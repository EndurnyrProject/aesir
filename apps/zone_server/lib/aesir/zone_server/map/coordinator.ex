defmodule Aesir.ZoneServer.Map.Coordinator do
  use GenServer

  require Logger

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SnapshotBuilder
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  # Default per-map delta-snapshot flush cadence (~10 Hz); overridable at runtime
  # via the `:broadcast_interval_ms` app env (design Part 1, Part 3).
  @broadcast_interval 100
  # Stop redundancy (design Part 1): a unit drained as STANDING is re-broadcast for
  # this many flushes so a lost "it stopped" can't strand it one cell off.
  @stop_echoes 3

  @standing 0
  @moving 1

  defstruct [
    :map_name,
    :map_data,
    :spawn_data,
    :npcs,
    :respawn_timers,
    :next_mob_id,
    :items,
    :weather,
    :pvp_enabled,
    :pk_enabled,
    :mob_supervisor_pid,
    recently_stopped: %{}
  ]

  @doc """
  Starts a map coordinator.
  """
  def start_link(opts) do
    map_name = Keyword.fetch!(opts, :map_name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(map_name))
  end

  @doc """
  Spawns an item on the ground.
  """
  def spawn_item(map_name, item_id, amount, x, y) do
    GenServer.cast(via_tuple(map_name), {:spawn_item, item_id, amount, x, y})
  end

  @doc """
  Changes map weather.
  """
  def set_weather(map_name, weather_type) do
    GenServer.cast(via_tuple(map_name), {:set_weather, weather_type})
  end

  @doc """
  Broadcasts an announcement to all players on the map.
  """
  def announce(map_name, message) do
    GenServer.cast(via_tuple(map_name), {:announce, message})
  end

  @doc """
  Gets map information.
  """
  def get_map_info(map_name) do
    GenServer.call(via_tuple(map_name), :get_info)
  end

  @impl true
  def init(opts) do
    map_name = Keyword.fetch!(opts, :map_name)

    # Load map geometry
    map_data =
      case MapCache.get(map_name) do
        {:ok, data} -> data
        {:error, _} -> nil
      end

    # Load spawn configurations
    spawn_data =
      case MobManagement.get_spawns_for_map(map_name) do
        {:ok, spawns} -> spawns
        {:error, _} -> []
      end

    # Start mob supervisor for this map
    {:ok, mob_supervisor_pid} = MobSupervisor.start_link(map_name)

    state = %__MODULE__{
      map_name: map_name,
      map_data: map_data,
      spawn_data: spawn_data,
      npcs: %{},
      respawn_timers: %{},
      next_mob_id: 1,
      items: %{},
      weather: :clear,
      pvp_enabled: Keyword.get(opts, :pvp_enabled, false),
      pk_enabled: Keyword.get(opts, :pk_enabled, false),
      mob_supervisor_pid: mob_supervisor_pid,
      recently_stopped: %{}
    }

    if spawn_data != [] do
      Process.send_after(self(), :initial_spawn, 100)
    end

    schedule_cleanup()
    schedule_broadcast()

    {:ok, state}
  end

  @doc """
  Notifies the coordinator that a mob has died.
  """
  def mob_died(map_name, instance_id) do
    clean_name = String.replace_suffix(map_name, ".gat", "")
    GenServer.cast(via_tuple(clean_name), {:mob_died, instance_id})
  end

  @doc """
  Gets information about all mobs on the map.
  """
  def get_mob_info(map_name) do
    GenServer.call(via_tuple(map_name), :get_mob_info)
  end

  @impl true
  def handle_cast({:spawn_item, item_id, amount, x, y}, state) do
    instance_id = generate_item_id()

    item = %{
      id: instance_id,
      item_id: item_id,
      amount: amount,
      x: x,
      y: y,
      spawned_at: System.system_time(:second)
    }

    new_items = Map.put(state.items, instance_id, item)

    broadcast_item_spawn(state.map_name, item, x, y)

    {:noreply, %{state | items: new_items}}
  end

  @impl true
  def handle_cast({:set_weather, weather_type}, state) do
    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{state.map_name}",
      {:weather_changed, weather_type}
    )

    {:noreply, %{state | weather: weather_type}}
  end

  @impl true
  def handle_cast({:announce, message}, state) do
    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{state.map_name}",
      {:map_announcement, message}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:mob_died, instance_id}, state) do
    # Get mob data from UnitRegistry to find spawn config
    case UnitRegistry.get_unit(:mob, instance_id) do
      {:error, :not_found} ->
        {:noreply, state}

      {:ok, {_module, mob, _pid}} ->
        # Unregister from UnitRegistry
        UnitRegistry.unregister_unit(:mob, instance_id)

        # Remove from spatial index
        SpatialIndex.remove_unit(:mob, instance_id)

        # Schedule respawn with spawn config
        spawn_config = mob.spawn_ref

        timer_ref =
          Process.send_after(
            self(),
            {:respawn_mob, spawn_config},
            spawn_config.respawn_time
          )

        # Store timer with spawn config for cleanup
        new_timers = Map.put(state.respawn_timers, instance_id, {timer_ref, spawn_config})

        Logger.debug(
          "Mob #{instance_id} died on #{state.map_name}, respawning in #{spawn_config.respawn_time}ms"
        )

        {:noreply, %{state | respawn_timers: new_timers}}
    end
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = %{
      map_name: state.map_name,
      weather: state.weather,
      pvp_enabled: state.pvp_enabled,
      pk_enabled: state.pk_enabled,
      item_count: map_size(state.items),
      npc_count: map_size(state.npcs),
      player_count: SpatialIndex.count_players_on_map(state.map_name),
      mob_count: UnitRegistry.count_units_by_type(:mob)
    }

    {:reply, info, state}
  end

  @impl true
  def handle_call(:get_mob_info, _from, state) do
    mob_processes = MobSupervisor.get_mob_processes(state.map_name)

    mob_info =
      mob_processes
      |> Enum.map(fn pid ->
        try do
          case GenServer.call(pid, :get_state, 1000) do
            %MobState{} = mob ->
              %{
                instance_id: mob.instance_id,
                mob_id: mob.mob_id,
                name: mob.mob_data.name,
                position: {mob.x, mob.y},
                hp: mob.hp,
                max_hp: mob.max_hp,
                ai_state: mob.ai_state,
                is_dead: mob.is_dead
              }

            _ ->
              nil
          end
        catch
          :exit, _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:reply, mob_info, state}
  end

  @impl true
  def handle_info(:initial_spawn, state) do
    Logger.info("Starting initial mob spawn for #{state.map_name}")
    state = spawn_all_mobs(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:respawn_mob, spawn_config}, state) do
    Logger.debug("Respawning mob on #{state.map_name}")
    state = spawn_single_mob(spawn_config, state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:broadcast_tick, state) do
    schedule_broadcast()

    {deliveries, recently_stopped} =
      flush_snapshots(state.map_name, state.recently_stopped, ServerTick.now())

    Enum.each(deliveries, fn {pid, chunks} ->
      Enum.each(chunks, &PlayerSession.send_packet(pid, &1))
    end)

    {:noreply, %{state | recently_stopped: recently_stopped}}
  end

  @impl true
  def handle_info(:cleanup_items, state) do
    # Remove items older than 3 minutes
    now = System.system_time(:second)
    # 3 minutes
    timeout = 180

    new_items =
      state.items
      |> Enum.reject(fn {_id, item} ->
        now - item.spawned_at > timeout
      end)
      |> Map.new()

    expired = Map.keys(state.items) -- Map.keys(new_items)

    Enum.each(expired, fn item_id ->
      item = state.items[item_id]
      broadcast_item_remove(state.map_name, item_id, item.x, item.y)
    end)

    schedule_cleanup()

    {:noreply, %{state | items: new_items}}
  end

  @doc """
  Computes the per-observer delta-snapshot deliveries for one flush.

  Drains the map's dirty set, folds it into `recently_stopped` (stop redundancy),
  builds a `%Aesir.Net.SnapshotEntity{}` per dirty/echoed unit, and for each
  observing player on the map returns the dirty entities within that player's
  `view_range` (Manhattan, the metric `SpatialIndex` uses) excluding the player's
  own entity, packed into datagram-sized `%Aesir.Net.Snapshot{}` chunks sharing
  the given `server_tick`.

  Returns `{deliveries, new_recently_stopped}` where `deliveries` is
  `[{player_pid, [chunk]}]`. Performs no sends, so the caller decides delivery;
  this keeps the timer-driven flush testable in isolation.
  """
  @spec flush_snapshots(
          String.t(),
          %{{atom(), integer()} => non_neg_integer()},
          non_neg_integer()
        ) ::
          {[{pid(), [NetSnapshot.t()]}], %{{atom(), integer()} => non_neg_integer()}}
  def flush_snapshots(map_name, recently_stopped, server_tick) do
    drained = Movement.drain_dirty(map_name)
    recently_stopped = update_recently_stopped(recently_stopped, drained)

    broadcast_keys =
      drained
      |> Enum.map(fn {unit_type, unit_id, _move_state} -> {unit_type, unit_id} end)
      |> Enum.concat(Map.keys(recently_stopped))
      |> Enum.uniq()

    keyed_entities =
      Enum.flat_map(broadcast_keys, fn key ->
        case SnapshotBuilder.entities_for([key]) do
          [entity] -> [{key, entity}]
          [] -> []
        end
      end)

    deliveries =
      map_name
      |> SpatialIndex.get_players_on_map()
      |> Enum.flat_map(&observer_delivery(&1, keyed_entities, server_tick))

    {deliveries, recently_stopped}
  end

  @spec update_recently_stopped(
          %{{atom(), integer()} => non_neg_integer()},
          [{atom(), integer(), 0 | 1}]
        ) :: %{{atom(), integer()} => non_neg_integer()}
  defp update_recently_stopped(recently_stopped, drained) do
    decremented =
      recently_stopped
      |> Enum.flat_map(fn {key, remaining} ->
        if remaining - 1 > 0, do: [{key, remaining - 1}], else: []
      end)
      |> Map.new()

    Enum.reduce(drained, decremented, fn
      {unit_type, unit_id, @standing}, acc ->
        Map.put(acc, {unit_type, unit_id}, @stop_echoes)

      {unit_type, unit_id, @moving}, acc ->
        Map.delete(acc, {unit_type, unit_id})
    end)
  end

  @spec observer_delivery(
          integer(),
          [{{atom(), integer()}, SnapshotEntity.t()}],
          non_neg_integer()
        ) :: [{pid(), [NetSnapshot.t()]}]
  defp observer_delivery(char_id, keyed_entities, server_tick) do
    with {:ok, pid} <- UnitRegistry.get_player_pid(char_id),
         {:ok, {_module, %PlayerState{} = state, _pid}} <- UnitRegistry.get_unit(:player, char_id),
         visible when visible != [] <-
           visible_entities(keyed_entities, char_id, state.x, state.y, state.view_range) do
      [{pid, SnapshotBuilder.chunks_for(visible, {state.x, state.y}, server_tick)}]
    else
      _ -> []
    end
  end

  @spec visible_entities(
          [{{atom(), integer()}, SnapshotEntity.t()}],
          integer(),
          integer(),
          integer(),
          integer()
        ) :: [SnapshotEntity.t()]
  defp visible_entities(keyed_entities, char_id, px, py, view_range) do
    keyed_entities
    |> Enum.reject(fn {key, _entity} -> key == {:player, char_id} end)
    |> Enum.filter(fn {_key, entity} ->
      abs(entity.x - px) + abs(entity.y - py) <= view_range
    end)
    |> Enum.map(fn {_key, entity} -> entity end)
  end

  defp via_tuple(map_name) do
    {:via, Registry, {Aesir.ZoneServer.MapRegistry, map_name}}
  end

  # Mob Spawning Functions

  defp spawn_all_mobs(state) do
    Enum.reduce(state.spawn_data, state, fn spawn_config, acc_state ->
      spawn_mob_group(spawn_config, acc_state)
    end)
  end

  defp spawn_mob_group(spawn_config, state) do
    Enum.reduce(1..spawn_config.amount, state, fn _i, acc_state ->
      spawn_single_mob(spawn_config, acc_state)
    end)
  end

  defp spawn_single_mob(spawn_config, state) do
    case MobManagement.get_mob_by_id(spawn_config.mob) do
      {:ok, mob_data} ->
        do_spawn_single_mob(spawn_config, mob_data, state)

      {:error, :mob_not_found} ->
        Logger.warning(
          "Spawn for #{state.map_name} references unknown mob id #{inspect(spawn_config.mob)}; skipping"
        )

        state
    end
  end

  defp do_spawn_single_mob(spawn_config, mob_data, state) do
    instance_id = generate_mob_instance_id()

    {x, y} = calculate_spawn_position(spawn_config.spawn_area, state.map_data)

    map_name_with_gat =
      if String.ends_with?(state.map_name, ".gat") do
        state.map_name
      else
        state.map_name <> ".gat"
      end

    mob_state = MobState.new(instance_id, mob_data, spawn_config, map_name_with_gat, x, y)

    case MobSupervisor.spawn_mob(state.map_name, mob_state) do
      {:ok, mob_pid} ->
        UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, mob_pid)

        Logger.debug(
          "Spawned mob #{mob_data.name} (#{instance_id}) at #{x},#{y} on #{state.map_name} with pid #{inspect(mob_pid)}"
        )

        %{state | next_mob_id: state.next_mob_id + 1}

      {:error, reason} ->
        Logger.error(
          "Failed to start mob session #{inspect(spawn_config.mob)}: #{inspect(reason)}"
        )

        state
    end
  end

  # Random position within spawn area
  # spawn_area.x/y are center coordinates
  # spawn_area.xs/ys are radius from center
  defp calculate_spawn_position(spawn_area, _map_data) do
    x =
      if spawn_area.xs > 0 do
        spawn_area.x + :rand.uniform(spawn_area.xs * 2 + 1) - spawn_area.xs - 1
      else
        spawn_area.x
      end

    y =
      if spawn_area.ys > 0 do
        spawn_area.y + :rand.uniform(spawn_area.ys * 2 + 1) - spawn_area.ys - 1
      else
        spawn_area.y
      end

    # TODO: Validate walkable with map_data when available
    {max(0, x), max(0, y)}
  end

  defp generate_mob_instance_id do
    # Generate a random ID in the safe range and check if it's already in use globally
    # Range: 2 to 1,999,999 (following rAthena's MIN_FLOORITEM to MAX_FLOORITEM)
    min_id = 2
    max_id = 1_999_999

    find_unused_mob_id(min_id, max_id)
  end

  defp find_unused_mob_id(min_id, max_id) do
    # Generate random ID in range
    candidate_id = :rand.uniform(max_id - min_id) + min_id

    # Check if this ID is already registered as a mob globally
    case UnitRegistry.get_unit(:mob, candidate_id) do
      {:error, :not_found} ->
        # ID is free globally, use it
        candidate_id

      {:ok, _} ->
        # ID is taken, try again
        find_unused_mob_id(min_id, max_id)
    end
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup_items, 60_000)

  defp schedule_broadcast, do: Process.send_after(self(), :broadcast_tick, broadcast_interval())

  @doc "The per-map delta-snapshot flush interval in milliseconds."
  @spec broadcast_interval() :: pos_integer()
  def broadcast_interval,
    do: Application.get_env(:zone_server, :broadcast_interval_ms, @broadcast_interval)

  defp generate_item_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16()

  defp broadcast_item_spawn(map_name, item, x, y) do
    cell_x = div(x, 8)
    cell_y = div(y, 8)

    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{map_name}:cell:#{cell_x}:#{cell_y}",
      {:item_spawned, item}
    )
  end

  defp broadcast_item_remove(map_name, item_id, x, y) do
    cell_x = div(x, 8)
    cell_y = div(y, 8)

    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{map_name}:cell:#{cell_x}:#{cell_y}",
      {:item_removed, item_id}
    )
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Map coordinator for #{state.map_name} terminating: #{inspect(reason)}")

    # Terminate all mobs on this map
    if state.mob_supervisor_pid do
      MobSupervisor.terminate_all_mobs(state.map_name)
    end

    :ok
  end
end
