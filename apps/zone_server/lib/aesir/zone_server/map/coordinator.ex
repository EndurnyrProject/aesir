defmodule Aesir.ZoneServer.Map.Coordinator do
  use GenServer

  require Logger

  alias Aesir.Commons.InterServer.PubSub, as: ServerPubSub
  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.ItemVanished
  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.BossRespawn
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SnapshotBuilder
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.WorldId
  alias Phoenix.PubSub

  # Default per-map delta-snapshot flush cadence (~10 Hz); overridable at runtime
  # via the `:broadcast_interval_ms` app env (design Part 1, Part 3).
  @broadcast_interval 100
  # Stop redundancy (design Part 1): a unit drained as STANDING is re-broadcast for
  # this many flushes so a lost "it stopped" can't strand it one cell off.
  @stop_echoes 3

  @standing 0
  @moving 1

  # rAthena `flooritem_lifetime`: a ground item despawns 60 s after it lands.
  @ground_item_lifetime_ms 60_000
  # Cadence of the ground-item expiry sweep.
  @ground_item_sweep_ms 10_000

  # Tick cadence while the map has no connected observers: just often enough
  # to notice one arriving, instead of burning the 10 Hz snapshot loop on an
  # unobserved map. Connected corpses remain observers and keep the fast cadence.
  @idle_broadcast_interval 1000
  # How long a map must stay empty before its mobs are put to sleep, so players
  # hopping between adjacent maps don't churn sleep/wake sweeps.
  @mob_sleep_grace 30_000

  # Retry delay when a spawn attempt finds no walkable/unblocked cell (e.g. a
  # fixed spawn point temporarily vetoed by a dynamic blocker like an Ice
  # Wall). Short and fixed rather than the spawn's own respawn_time, so the
  # mob comes back as soon as the blocker clears instead of after a possibly
  # long respawn window.
  @spawn_retry_delay 5_000

  defstruct [
    :map_name,
    :map_data,
    :spawn_data,
    :npcs,
    :respawn_timers,
    :next_mob_id,
    :weather,
    :pvp_enabled,
    :pk_enabled,
    :mob_supervisor_pid,
    :empty_since,
    boss_deadlines: %{},
    mobs_spawned: false,
    mobs_awake: false,
    recently_stopped: %{}
  ]

  @typedoc "Per-map coordinator state."
  @type t :: %__MODULE__{}

  @doc """
  Starts a map coordinator.
  """
  def start_link(opts) do
    map_name = Keyword.fetch!(opts, :map_name)
    {name, opts} = Keyword.pop(opts, :name, via_tuple(map_name))

    case name do
      nil -> GenServer.start_link(__MODULE__, opts)
      _ -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Places rolled drops on the ground around `{x, y}`.

  Each entry is `{nameid, amount, item_x, item_y, identified}` as produced by
  `DropCalculator` (scatter already resolved). The coordinator is the single
  writer of the ground-item store, so placement routes through here. Pass an
  `ownership:` option to stamp pickup rights onto every item in the call.
  """
  @spec drop_items(
          String.t(),
          [
            {non_neg_integer(), pos_integer(), non_neg_integer(), non_neg_integer(), boolean()}
          ],
          integer(),
          integer(),
          keyword()
        ) ::
          :ok
  def drop_items(map_name, items, x, y, opts \\ []) do
    GenServer.cast(server(map_name), {:drop_items, items, x, y, opts})
  end

  @doc """
  Atomically claims the ground item `ground_id` for `char_id`.

  Returns `{:ok, GroundItem.t()}` for the winner (and broadcasts the vanish to
  in-range players), `{:error, :protected}` when pickup rights deny the claim,
  or `{:error, :gone}` if it was already taken or expired.
  """
  @spec claim_item(String.t(), pos_integer(), integer(), LootOwnership.party_ctx()) ::
          {:ok, GroundItem.t()} | {:error, :gone} | {:error, :protected}
  def claim_item(
        map_name,
        ground_id,
        char_id,
        party_ctx \\ %{party_id: 0, pickup_share: false}
      ) do
    GenServer.call(server(map_name), {:claim_item, ground_id, char_id, party_ctx})
  end

  @doc """
  Changes map weather.
  """
  def set_weather(map_name, weather_type) do
    GenServer.cast(server(map_name), {:set_weather, weather_type})
  end

  @doc """
  Gets map information.
  """
  def get_map_info(map_name) do
    GenServer.call(server(map_name), :get_info)
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

    # Start the mob supervisor for this map. Under a per-test coordinator a
    # per-test supervisor is already registered in ProcessTree; reuse it instead
    # of re-registering (which would collide with the globally-booted one).
    mob_supervisor_pid =
      case ProcessTree.get({MobSupervisor, map_name}) do
        nil ->
          {:ok, pid} = MobSupervisor.start_link(map_name)
          pid

        pid when is_pid(pid) ->
          pid
      end

    state = %__MODULE__{
      map_name: map_name,
      map_data: map_data,
      spawn_data: spawn_data,
      npcs: %{},
      respawn_timers: %{},
      next_mob_id: 1,
      weather: :clear,
      pvp_enabled: Keyword.get(opts, :pvp_enabled, false),
      pk_enabled: Keyword.get(opts, :pk_enabled, false),
      mob_supervisor_pid: mob_supervisor_pid,
      recently_stopped: %{},
      # Boot-reconciled boss deadlines, consulted (never acted on) by this
      # map's first spawn. See `spawn_initial_mob/2`.
      boss_deadlines: BossRespawn.deadlines_for(map_name)
    }

    # Mobs are spawned lazily on the first tick that sees a player on this map
    # (see :broadcast_tick), so boot doesn't create 60k+ mob processes at once.
    ServerPubSub.subscribe_to_announcements()
    schedule_item_sweep()
    schedule_broadcast(idle_broadcast_interval())

    {:ok, state}
  end

  @doc """
  Notifies the coordinator that a mob has died.

  `killer_char_id` is the reward-owner character ID of the killing blow;
  rootless final sources and despawns pass `nil`. When the dying mob carries
  an `owner_event` (rAthena OnMyMobDead) and that owner resolves to a live
  player session, the event fires attached to that player; anything else
  (no `owner_event`, no reward owner, or an offline owner) fires nothing.
  """
  @spec mob_died(String.t(), integer(), integer() | nil) :: :ok
  def mob_died(map_name, instance_id, killer_char_id \\ nil) do
    clean_name = String.replace_suffix(map_name, ".gat", "")
    GenServer.cast(server(clean_name), {:mob_died, instance_id, killer_char_id})
  end

  @doc """
  Summons a single mob at `{x, y}` and registers it so it is attackable.

  Runs the same spawn machinery as the map's own spawns (collision-checked
  instance id, `MobState` build, supervised session, and `UnitRegistry`
  registration), so the mob can be targeted, damaged and killed. Summoned mobs
  carry a respawn time of 0 and are not re-spawned on death.

  A non-positive `x` or `y` picks a random walkable cell, mirroring rAthena's
  `mob_once_spawn` (script `monster "map",0,0,...`).

  Returns `{:ok, instance_id}`, or `{:error, :map_not_found}` when no
  coordinator runs for `map_name`, or `{:error, reason}` from the spawn.
  """
  @spec summon_mob(String.t(), integer(), integer(), integer(), keyword()) ::
          {:ok, integer()} | {:error, term()}
  def summon_mob(map_name, mob_id, x, y, opts \\ []) do
    clean_name = String.replace_suffix(map_name, ".gat", "")

    case lookup_server(clean_name) do
      {:ok, _pid} ->
        GenServer.call(server(clean_name), {:summon_mob, mob_id, x, y, opts})

      [] ->
        {:error, :map_not_found}
    end
  end

  @doc """
  Gets information about all mobs on the map.
  """
  def get_mob_info(map_name) do
    GenServer.call(server(map_name), :get_mob_info)
  end

  @impl true
  def handle_cast({:drop_items, items, _x, _y, opts}, state) do
    stamp = ownership_stamp(opts)

    Enum.each(items, fn {nameid, amount, item_x, item_y, identified} ->
      item = GroundItem.new(nameid, amount, item_x, item_y, identified, stamp)
      GroundItemStore.put(state.map_name, item)

      Broadcast.to_in_range(
        state.map_name,
        item_x,
        item_y,
        Config.view_range(),
        %ItemOnGround{
          ground_id: item.id,
          nameid: item.nameid,
          amount: item.amount,
          x: item.x,
          y: item.y,
          sub_x: item.sub_x,
          sub_y: item.sub_y,
          identified: item.identified,
          is_falling: true
        }
      )
    end)

    {:noreply, state}
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
  def handle_cast({:mob_died, instance_id, killer_char_id}, state) do
    # Get mob data from UnitRegistry to find spawn config
    case UnitRegistry.get_unit(:mob, instance_id) do
      {:error, :not_found} ->
        {:noreply, state}

      {:ok, {module, mob, _pid}} ->
        # Unregister from UnitRegistry
        UnitRegistry.unregister_unit(:mob, instance_id)

        # Remove from spatial index
        SpatialIndex.remove_unit(:mob, instance_id)

        dispatch_owner_event(mob.owner_event, killer_char_id)

        {:noreply, schedule_mob_respawn(state, instance_id, module, mob)}
    end
  end

  # Summoned mobs have no map spawn line; death is terminal for them.
  defp schedule_mob_respawn(state, _instance_id, _module, %{spawn_ref: %{summoned: true}}),
    do: state

  defp schedule_mob_respawn(state, instance_id, module, mob) do
    spawn_config = mob.spawn_ref
    boss? = module.is_boss?(mob)
    delay = respawn_delay(spawn_config, boss?)

    if boss? do
      respawn_at = DateTime.add(DateTime.utc_now(), delay, :millisecond)
      BossRespawn.write(state.map_name, spawn_config.mob, respawn_at)
    end

    timer_ref = Process.send_after(self(), {:respawn_mob, spawn_config}, delay)
    new_timers = Map.put(state.respawn_timers, instance_id, {timer_ref, spawn_config})

    Logger.debug("Mob #{instance_id} died on #{state.map_name}, respawning in #{delay}ms")

    %{state | respawn_timers: new_timers}
  end

  defp ownership_stamp(opts) do
    case Keyword.fetch(opts, :ownership) do
      :error ->
        []

      {:ok, {%LootOwnership{first: nil, second: nil, third: nil}, boss?}}
      when is_boolean(boss?) ->
        []

      {:ok, {%LootOwnership{} = ownership, boss?}} when is_boolean(boss?) ->
        owners = {ownership.first, ownership.second, ownership.third}
        unlock_at = LootOwnership.deadlines(boss?, System.monotonic_time(:millisecond))
        [owners: owners, unlock_at: unlock_at]

      {:ok, {{nil, nil, nil}, unlock_at}} when tuple_size(unlock_at) == 3 ->
        []

      {:ok, {owners, unlock_at}} when tuple_size(owners) == 3 and tuple_size(unlock_at) == 3 ->
        [owners: owners, unlock_at: unlock_at]
    end
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = %{
      map_name: state.map_name,
      weather: state.weather,
      pvp_enabled: state.pvp_enabled,
      pk_enabled: state.pk_enabled,
      npc_count: map_size(state.npcs),
      player_count: SpatialIndex.count_players_on_map(state.map_name),
      mob_count: UnitRegistry.count_units_by_type(:mob)
    }

    {:reply, info, state}
  end

  @impl true
  def handle_call({:claim_item, ground_id, char_id, party_ctx}, _from, state) do
    with {:ok, item} <- GroundItemStore.get(state.map_name, ground_id),
         :ok <-
           LootOwnership.can_claim?(
             item,
             char_id,
             party_ctx,
             System.monotonic_time(:millisecond)
           ),
         {:ok, %GroundItem{} = claimed} <- GroundItemStore.claim(state.map_name, ground_id) do
      Broadcast.to_in_range(
        state.map_name,
        claimed.x,
        claimed.y,
        Config.view_range(),
        %ItemVanished{ground_id: ground_id, reason: :PICKED_UP}
      )

      {:reply, {:ok, claimed}, state}
    else
      {:error, reason} when reason in [:gone, :protected] ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:summon_mob, mob_id, x, y, opts}, _from, state) do
    case MobManagement.get_mob_by_id(mob_id) do
      {:ok, mob_data} ->
        case summon_position({x, y}, state.map_data) do
          {:ok, position} ->
            {result, new_state} = place_mob(mob_data, position, opts, state)
            {:reply, result, new_state}

          {:error, :no_walkable_cell} = error ->
            {:reply, error, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
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
  def handle_info({:announcement, packet}, state) do
    Announcement.deliver_local(packet, state.map_name)
    {:noreply, state}
  end

  @impl true
  def handle_info({:server_announce, event}, state) do
    PubSub.broadcast(Aesir.PubSub, "map:#{state.map_name}", {:map_announcement, event.message})
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
    observers = SpatialIndex.get_players_on_map(state.map_name)
    has_observers = observers != []
    has_living_players = Enum.any?(observers, &living_player?/1)
    state = manage_mob_activity(has_living_players, state)

    state =
      if has_observers do
        {deliveries, recently_stopped} =
          flush_snapshots(state.map_name, state.recently_stopped, ServerTick.now())

        Enum.each(deliveries, fn {pid, chunks} ->
          Enum.each(chunks, &PlayerSession.send_packet(pid, &1))
        end)

        %{state | recently_stopped: recently_stopped}
      else
        # Nobody is observing: keep the dirty set from accumulating while mobs
        # finish their walks, but skip snapshot building entirely.
        Movement.drain_dirty(state.map_name)
        %{state | recently_stopped: %{}}
      end

    schedule_broadcast(
      if has_observers, do: broadcast_interval(), else: idle_broadcast_interval()
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(:expire_ground_items, state) do
    state.map_name
    |> GroundItemStore.expire_due(System.monotonic_time(:millisecond), @ground_item_lifetime_ms)
    |> Enum.each(fn %GroundItem{} = item ->
      Broadcast.to_in_range(
        state.map_name,
        item.x,
        item.y,
        Config.view_range(),
        %ItemVanished{ground_id: item.id, reason: :EXPIRED}
      )
    end)

    schedule_item_sweep()

    {:noreply, state}
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
           visible_entities(
             keyed_entities,
             char_id,
             state.x,
             state.y,
             state.view_range,
             state.visible_homunculi
           ) do
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
          integer(),
          MapSet.t(integer())
        ) :: [SnapshotEntity.t()]
  defp visible_entities(keyed_entities, char_id, px, py, view_range, visible_homunculi) do
    keyed_entities
    |> Enum.reject(fn
      {{:player, ^char_id}, _entity} -> true
      {{:homunculus, gid}, _entity} -> not MapSet.member?(visible_homunculi, gid)
      _other -> false
    end)
    |> Enum.filter(fn {_key, entity} ->
      abs(entity.x - px) + abs(entity.y - py) <= view_range
    end)
    |> Enum.map(fn {_key, entity} -> entity end)
  end

  defp via_tuple(map_name) do
    {:via, Registry, {Aesir.ZoneServer.MapRegistry, map_name}}
  end

  defp server(map_name) do
    ProcessTree.get({__MODULE__, map_name}) || via_tuple(map_name)
  end

  defp lookup_server(map_name) do
    case ProcessTree.get({__MODULE__, map_name}) do
      nil -> Registry.lookup(Aesir.ZoneServer.MapRegistry, map_name)
      pid -> [{pid, :per_test}]
    end
  end

  # Mob Spawning Functions

  # Drives the mob population from living-player presence: the first living
  # player to reach the map triggers its initial spawn, a repopulated map wakes
  # its dormant mobs, and a map without living players sleeps them after grace.
  defp manage_mob_activity(true, state) do
    cond do
      not state.mobs_spawned ->
        Logger.debug("First player on #{state.map_name}, spawning mobs")

        # Summons/respawns that landed dormant before the first visit wake too.
        MobSupervisor.wake_all_mobs(state.map_name)

        %{state | mobs_spawned: true, mobs_awake: true, empty_since: nil}
        |> spawn_all_mobs()

      not state.mobs_awake ->
        Logger.debug("Players back on #{state.map_name}, waking mobs")
        MobSupervisor.wake_all_mobs(state.map_name)
        %{state | mobs_awake: true, empty_since: nil}

      true ->
        %{state | empty_since: nil}
    end
  end

  defp manage_mob_activity(false, %{mobs_awake: true} = state) do
    now = System.monotonic_time(:millisecond)
    empty_since = state.empty_since || now

    if now - empty_since >= mob_sleep_grace() do
      Logger.debug("#{state.map_name} empty for #{mob_sleep_grace()}ms, sleeping mobs")
      MobSupervisor.sleep_all_mobs(state.map_name)
      %{state | mobs_awake: false, empty_since: empty_since}
    else
      %{state | empty_since: empty_since}
    end
  end

  defp manage_mob_activity(false, state), do: state

  defp living_player?(character_id) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {_module, player_state, _pid}} -> Unit.living?(player_state)
      {:error, :not_found} -> false
    end
  end

  defp spawn_all_mobs(state) do
    Enum.reduce(state.spawn_data, state, fn spawn_config, acc_state ->
      spawn_mob_group(spawn_config, acc_state)
    end)
  end

  defp spawn_mob_group(spawn_config, state) do
    Enum.reduce(1..spawn_config.amount, state, fn _i, acc_state ->
      spawn_initial_mob(spawn_config, acc_state)
    end)
  end

  # The consumption side of boot reconciliation, and the only place a
  # reconciled deadline is read. A boss with no pending deadline, or one whose
  # deadline has already passed, spawns as part of the map's normal first
  # spawn; a deadline still in the future skips the spawn entirely -- leaving
  # the durable row intact -- and arms a timer for the remaining interval, so
  # every path yields exactly one boss.
  #
  # Deadlines are consumed one per spawned instance, so two pending rows for
  # the same mob id resolve to two skipped spawns rather than one.
  @spec spawn_initial_mob(MobSpawn.t(), t()) :: t()
  defp spawn_initial_mob(spawn_config, state) do
    case pop_deadline(state.boss_deadlines, spawn_config.mob) do
      :none ->
        spawn_single_mob(spawn_config, state)

      {deadline, boss_deadlines} ->
        state = %{state | boss_deadlines: boss_deadlines}
        remaining_ms = DateTime.diff(deadline, DateTime.utc_now(), :millisecond)

        if remaining_ms > 0 do
          Logger.debug(
            "Boss #{spawn_config.mob} on #{state.map_name} still pending, respawning in #{remaining_ms}ms"
          )

          Process.send_after(self(), {:respawn_mob, spawn_config}, remaining_ms)
          state
        else
          spawn_single_mob(spawn_config, state)
        end
    end
  end

  @spec pop_deadline(BossRespawn.deadlines(), integer()) ::
          :none | {DateTime.t(), BossRespawn.deadlines()}
  defp pop_deadline(boss_deadlines, mob_id) do
    case Map.get(boss_deadlines, mob_id) do
      [deadline | rest] -> {deadline, Map.put(boss_deadlines, mob_id, rest)}
      _empty_or_absent -> :none
    end
  end

  # Clearing the durable deadline lives here rather than in the `:respawn_mob`
  # handler because this is the one path every spawn funnels through, and
  # `mob_data` is already loaded. The delete is gated on boss mode so ordinary
  # mob respawns issue no query.
  #
  # CONTRACT for boot reconciliation: a boss whose deadline is still in the
  # future must be skipped *before* reaching this function, so its row survives
  # to be re-armed. Placing a boss here always means "it is spawning now", which
  # is precisely when its pending deadline should be consumed.
  defp spawn_single_mob(spawn_config, state) do
    case MobManagement.get_mob_by_id(spawn_config.mob) do
      {:ok, mob_data} ->
        if :boss in mob_data.modes do
          BossRespawn.delete(state.map_name, spawn_config.mob)
        end

        do_spawn_single_mob(spawn_config, mob_data, state)

      {:error, :mob_not_found} ->
        Logger.warning(
          "Spawn for #{state.map_name} references unknown mob id #{inspect(spawn_config.mob)}; skipping"
        )

        state
    end
  end

  defp do_spawn_single_mob(spawn_config, mob_data, state) do
    case calculate_spawn_position(spawn_config.spawn_area, state.map_data) do
      {:ok, {x, y}} ->
        {_result, new_state} = place_mob(mob_data, {x, y}, [spawn_ref: spawn_config], state)
        new_state

      {:error, :no_walkable_cell} ->
        Logger.debug(
          "No walkable cell for mob #{inspect(spawn_config.mob)} spawn on #{state.map_name}; " <>
            "retrying in #{spawn_retry_delay()}ms"
        )

        Process.send_after(self(), {:respawn_mob, spawn_config}, spawn_retry_delay())
        state
    end
  end

  # NOTE: `:aggressive` is accepted but deferred — forcing aggressive AI means
  # overriding mob_data.modes, which the AI state machine reads in several places;
  # left for a follow-up so summons don't ship a half-correct mode override.
  defp place_mob(mob_data, {x, y}, opts, state) do
    instance_id = generate_mob_instance_id()
    spawn_ref = Keyword.get_lazy(opts, :spawn_ref, fn -> summon_spawn_ref(mob_data, x, y) end)

    mob_state =
      instance_id
      |> MobState.new(mob_data, spawn_ref, state.map_name, x, y)
      |> MobState.set_owner_event(Keyword.get(opts, :event))
      |> MobState.set_master(Keyword.get(opts, :master_id))
      |> MobState.configure_summon(opts)

    # Respawns and summons on a currently-empty map start dormant; the
    # coordinator wakes them when a player next shows up.
    session_opts = [awake: state.mobs_awake, lifetime_ms: Keyword.get(opts, :lifetime_ms)]

    case MobSupervisor.spawn_mob(state.map_name, mob_state, session_opts) do
      {:ok, mob_pid} ->
        UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, mob_pid)
        {{:ok, instance_id}, %{state | next_mob_id: state.next_mob_id + 1}}

      {:error, reason} ->
        UnitRegistry.release_unit_id(instance_id, :mob)
        Logger.error("Failed to start mob session #{inspect(mob_data.id)}: #{inspect(reason)}")
        {{:error, reason}, state}
    end
  end

  # Dispatches a dying mob's OnMyMobDead owner event (rAthena `mobkillevent`)
  # when it carries one and the killing blow lands from a live player session
  # -- a mob-vs-mob kill, a despawn, or an offline killer all fire nothing,
  # matching rAthena's "must be killed by a player" semantics. The DSL already
  # validated the ref's "Name::OnLabel" shape at spawn time, so a split
  # failure here would only mean the field was set some other way; treated the
  # same as no event rather than crashing the death path over it.
  @spec dispatch_owner_event(String.t() | nil, integer() | nil) :: :ok
  defp dispatch_owner_event(nil, _killer_char_id), do: :ok
  defp dispatch_owner_event(_owner_event, nil), do: :ok

  defp dispatch_owner_event(owner_event, killer_char_id) do
    with [name, label] <- String.split(owner_event, "::", parts: 2),
         {:ok, pid} <- UnitRegistry.get_player_pid(killer_char_id),
         [{module, placement} | _rest] <- NpcRegistry.by_name(name) do
      gid = NpcRegistry.entity_id(placement)
      PlayerSession.run_attached_event(pid, module, gid, label)
      :ok
    else
      {:error, :not_found} ->
        :ok

      [] ->
        Logger.warning("npc owner event: unknown name in #{inspect(owner_event)}")
        :ok

      _malformed ->
        Logger.warning("npc owner event: malformed ref #{inspect(owner_event)}")
        :ok
    end
  end

  # Boss respawn delay: base + a uniform random offset in `0..respawn_variance`,
  # scaled by the configured boss percentage, floored at 1000 ms. Non-boss mobs
  # keep their current fixed `respawn_time`, ignoring the variance field
  # entirely -- applying variance game-wide is a deliberately deferred decision
  # (architecture doc, boss-monsters spec).
  #
  @spec respawn_delay(MobSpawn.t(), boolean()) :: pos_integer()
  defp respawn_delay(%MobSpawn{respawn_time: respawn_time}, false), do: respawn_time

  defp respawn_delay(%MobSpawn{respawn_time: respawn_time, respawn_variance: variance}, true) do
    (respawn_time + random_variance(variance))
    |> Kernel.*(Config.boss_respawn_delay_percentage())
    |> div(100)
    |> max(1000)
  end

  @spec random_variance(non_neg_integer()) :: non_neg_integer()
  defp random_variance(0), do: 0
  defp random_variance(variance) when variance > 0, do: :rand.uniform(variance + 1) - 1

  # NOTE: summoned mobs (Dead Branch etc.) have no map spawn config; we fabricate
  # a minimal MobSpawn marked summoned so death is terminal instead of respawning.
  defp summon_spawn_ref(mob_data, x, y) do
    %MobSpawn{
      mob: mob_data.id,
      amount: 1,
      respawn_time: 0,
      summoned: true,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }
  end

  # Picks a spawn cell using rAthena spawn-line semantics: `x: 0, y: 0` means a
  # random walkable cell anywhere on the map (the common case in imported spawn
  # data), `xs`/`ys` > 0 a random walkable cell in the area around `{x, y}`, and
  # a bare `{x, y}` the exact cell.
  @spawn_position_attempts 100

  defp calculate_spawn_position(%MobSpawn.SpawnArea{x: 0, y: 0}, %MapData{} = map_data) do
    random_walkable_cell(map_data, @spawn_position_attempts)
  end

  defp calculate_spawn_position(%MobSpawn.SpawnArea{xs: 0, ys: 0} = spawn_area, map_data) do
    fixed_position(map_data, max(spawn_area.x, 0), max(spawn_area.y, 0))
  end

  defp calculate_spawn_position(spawn_area, map_data) do
    random_area_cell(spawn_area, map_data, @spawn_position_attempts)
  end

  defp summon_position({x, y}, %MapData{} = map_data) when x <= 0 or y <= 0,
    do: random_walkable_cell(map_data, @spawn_position_attempts)

  defp summon_position({x, y}, map_data), do: fixed_position(map_data, max(x, 0), max(y, 0))

  defp fixed_position(%MapData{name: map_name}, x, y) do
    if Cell.dynamically_blocked?(map_name, x, y),
      do: {:error, :no_walkable_cell},
      else: {:ok, {x, y}}
  end

  defp fixed_position(_map_data, x, y), do: {:ok, {x, y}}

  defp random_walkable_cell(_map_data, 0), do: {:error, :no_walkable_cell}

  defp random_walkable_cell(%MapData{xs: width, ys: height} = map_data, attempts) do
    x = :rand.uniform(width) - 1
    y = :rand.uniform(height) - 1

    cond do
      Cell.traversable?(map_data.name, x, y) -> {:ok, {x, y}}
      attempts > 1 -> random_walkable_cell(map_data, attempts - 1)
      true -> {:error, :no_walkable_cell}
    end
  end

  defp random_area_cell(_spawn_area, _map_data, 0), do: {:error, :no_walkable_cell}

  defp random_area_cell(spawn_area, map_data, attempts) do
    x = spawn_area.x + :rand.uniform(spawn_area.xs * 2 + 1) - spawn_area.xs - 1
    y = spawn_area.y + :rand.uniform(spawn_area.ys * 2 + 1) - spawn_area.ys - 1

    cond do
      not match?(%MapData{}, map_data) -> {:error, :no_walkable_cell}
      Cell.traversable?(map_data.name, x, y) -> {:ok, {x, y}}
      attempts > 1 -> random_area_cell(spawn_area, map_data, attempts - 1)
      true -> {:error, :no_walkable_cell}
    end
  end

  # Range: 2 to 1,999,999 (following rAthena's MIN_FLOORITEM to MAX_FLOORITEM).
  defp generate_mob_instance_id do
    case WorldId.allocate(2..1_999_999, :mob) do
      {:ok, instance_id} -> instance_id
      {:error, :exhausted} -> raise "world ID range exhausted"
    end
  end

  defp schedule_item_sweep,
    do: Process.send_after(self(), :expire_ground_items, @ground_item_sweep_ms)

  defp schedule_broadcast(interval), do: Process.send_after(self(), :broadcast_tick, interval)

  @doc "The per-map delta-snapshot flush interval in milliseconds."
  @spec broadcast_interval() :: pos_integer()
  def broadcast_interval,
    do: Application.get_env(:zone_server, :broadcast_interval_ms, @broadcast_interval)

  @doc "The tick interval in milliseconds while a map has no players."
  @spec idle_broadcast_interval() :: pos_integer()
  def idle_broadcast_interval,
    do: Application.get_env(:zone_server, :idle_broadcast_interval_ms, @idle_broadcast_interval)

  @doc "How long a map must stay empty before its mobs are put to sleep."
  @spec mob_sleep_grace() :: pos_integer()
  def mob_sleep_grace,
    do: Application.get_env(:zone_server, :mob_sleep_grace_ms, @mob_sleep_grace)

  @doc "Retry delay when a spawn attempt finds no walkable/unblocked cell."
  @spec spawn_retry_delay() :: pos_integer()
  def spawn_retry_delay,
    do: Application.get_env(:zone_server, :spawn_retry_delay_ms, @spawn_retry_delay)

  @impl true
  def terminate(reason, state) do
    Logger.info("Map coordinator for #{state.map_name} terminating: #{inspect(reason)}")

    # Terminate all mobs on this map, then the (linked) supervisor itself so
    # it doesn't outlive the coordinator and orphan its Registry entry.
    if state.mob_supervisor_pid do
      MobSupervisor.terminate_all_mobs(state.map_name)
      MobSupervisor.stop(state.map_name)
    end

    :ok
  end
end
