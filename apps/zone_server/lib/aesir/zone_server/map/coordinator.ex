defmodule Aesir.ZoneServer.Map.Coordinator do
  use GenServer

  require Logger

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDataLoader
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

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
    :mob_supervisor_pid
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
      case MobDataLoader.get_spawns_for_map(map_name) do
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
      mob_supervisor_pid: mob_supervisor_pid
    }

    # Schedule initial mob spawns if any
    if length(spawn_data) > 0 do
      Process.send_after(self(), :initial_spawn, 100)
    end

    schedule_cleanup()

    {:ok, state}
  end

  @doc """
  Notifies the coordinator that a mob has died.
  """
  def mob_died(map_name, instance_id) do
    GenServer.cast(via_tuple(map_name), {:mob_died, instance_id})
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
            spawn_config.respawn_time * 1000
          )

        # Store timer with spawn config for cleanup
        new_timers = Map.put(state.respawn_timers, instance_id, {timer_ref, spawn_config})

        Logger.debug(
          "Mob #{instance_id} died on #{state.map_name}, respawning in #{spawn_config.respawn_time}s"
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
    instance_id = generate_mob_instance_id(state.map_name, state.next_mob_id)

    # Calculate spawn position
    {x, y} = calculate_spawn_position(spawn_config.spawn_area, state.map_data)

    # Get mob data
    case MobDataLoader.get_mob(spawn_config.mob_id) do
      {:ok, mob_data} ->
        # Create mob state with .gat suffix for client compatibility
        map_name_with_gat =
          if String.ends_with?(state.map_name, ".gat") do
            state.map_name
          else
            state.map_name <> ".gat"
          end

        mob_state = MobState.new(instance_id, mob_data, spawn_config, map_name_with_gat, x, y)

        # Spawn mob session under supervisor
        case MobSupervisor.spawn_mob(state.map_name, mob_state) do
          {:ok, mob_pid} ->
            # Register with UnitRegistry
            UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, mob_pid)

            Logger.debug(
              "Spawned mob #{mob_data.name} (#{instance_id}) at #{x},#{y} on #{state.map_name}"
            )

            # Update state - only increment next_mob_id
            %{state | next_mob_id: state.next_mob_id + 1}

          {:error, reason} ->
            Logger.error("Failed to start mob session #{spawn_config.mob_id}: #{inspect(reason)}")
            state
        end

      {:error, reason} ->
        Logger.error("Failed to load mob data #{spawn_config.mob_id}: #{inspect(reason)}")
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

  defp generate_mob_instance_id(map_name, local_id) do
    map_hash = :erlang.phash2(map_name, 65_536)
    map_hash * 1_000_000 + local_id
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup_items, 60_000)

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
