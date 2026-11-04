defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Manager do
  @moduledoc """
  Serializes every ground skill-unit mutation and drives interval/expiry ticks.

  Storage reads remain direct, while registration, callback updates, explicit
  state changes, and teardown pass through this process so the primary row and
  every secondary index change as one ordered operation.

  The process owns the public API, the tick, the movement passes (`appear`,
  `remove`, `step`, `trigger`) and the unit lifecycle events; the mutations
  themselves live in `Registration`, `GroupLifecycle`, `Traps`, `WaterBall`,
  `TrapTransition`, `Cells` and `Publisher`, all of which run in this process.
  """

  use GenServer

  require Logger

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cells
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.GroupLifecycle
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Handler
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Publisher
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Registration
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Traps
  alias Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimer
  alias Aesir.ZoneServer.Mmo.Skill.Unit.WaterBall
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @tick_interval 100
  @safetywall_skill_id 12

  @type server :: GenServer.server()
  @type mover :: {atom(), integer()}
  @type safetywall_absorb_result :: :pass | {:block, :keep | :remove}

  @doc "Starts the supervised skill-unit manager."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "Registers a fully prepared group before its placement is published."
  @spec register(Group.t()) :: :ok | {:error, term()}
  def register(%Group{} = group), do: register(default_server(), group)

  @doc false
  @spec register(server(), Group.t()) :: :ok | {:error, term()}
  def register(server, %Group{} = group), do: GenServer.call(server, {:register, group})

  @doc "Reveals hidden supported Hunter traps in an inclusive square area."
  @spec reveal_traps(String.t(), integer(), integer(), non_neg_integer()) ::
          {:ok, [non_neg_integer()]} | {:error, atom()}
  def reveal_traps(map_name, x, y, range),
    do: reveal_traps(default_server(), map_name, x, y, range)

  @doc false
  @spec reveal_traps(server(), String.t(), integer(), integer(), non_neg_integer()) ::
          {:ok, [non_neg_integer()]} | {:error, atom()}
  def reveal_traps(server, map_name, x, y, range)
      when is_binary(map_name) and is_integer(x) and is_integer(y) and is_integer(range) and
             range >= 0 do
    GenServer.call(server, {:reveal_traps, map_name, x, y, range})
  end

  @doc "Atomically reclaims one eligible trap owned by `owner` at a map cell."
  @spec reclaim_trap(mover(), String.t(), integer(), integer()) ::
          {:ok, %{group_id: non_neg_integer(), item_id: pos_integer() | nil}} | {:error, atom()}
  def reclaim_trap(owner, map_name, x, y),
    do: reclaim_trap(default_server(), owner, map_name, x, y)

  @doc false
  @spec reclaim_trap(server(), mover(), String.t(), integer(), integer()) ::
          {:ok, %{group_id: non_neg_integer(), item_id: pos_integer() | nil}} | {:error, atom()}
  def reclaim_trap(server, {owner_type, owner_id} = owner, map_name, x, y)
      when is_atom(owner_type) and is_integer(owner_id) and is_binary(map_name) and is_integer(x) and
             is_integer(y) do
    GenServer.call(server, {:reclaim_trap, owner, map_name, x, y})
  end

  @doc "Atomically springs one eligible armed trap at a map cell."
  @spec spring_trap(String.t(), integer(), integer()) ::
          {:ok, %{group_id: non_neg_integer(), expires_at: integer()}} | {:error, atom()}
  def spring_trap(map_name, x, y), do: spring_trap(default_server(), map_name, x, y)

  @doc false
  @spec spring_trap(server(), String.t(), integer(), integer()) ::
          {:ok, %{group_id: non_neg_integer(), expires_at: integer()}} | {:error, atom()}
  def spring_trap(server, map_name, x, y)
      when is_binary(map_name) and is_integer(x) and is_integer(y) do
    GenServer.call(server, {:spring_trap, map_name, x, y})
  end

  @doc "Merges skill-owned state into a live group without resurrecting a deleted one."
  @spec update_state(non_neg_integer(), map()) :: :ok
  def update_state(group_id, state), do: update_state(default_server(), group_id, state)

  @doc false
  @spec update_state(server(), non_neg_integer(), map()) :: :ok
  def update_state(server, group_id, state) do
    GenServer.call(server, {:update_state, group_id, state})
  end

  @doc "Atomically spends one Safety Wall hit and its shared HP budget."
  @spec absorb_safetywall_hit(non_neg_integer(), pos_integer()) :: safetywall_absorb_result()
  def absorb_safetywall_hit(group_id, damage) do
    absorb_safetywall_hit(default_server(), group_id, damage)
  end

  @doc false
  @spec absorb_safetywall_hit(server(), non_neg_integer(), pos_integer()) ::
          safetywall_absorb_result()
  def absorb_safetywall_hit(server, group_id, damage)
      when is_integer(damage) and damage > 0 do
    GenServer.call(server, {:absorb_safetywall_hit, group_id, damage})
  end

  @doc """
  Removes coordinates from a live group, expiring the group with its last cell.

  Coordinates the group no longer owns are ignored, so repeated removals
  converge instead of failing.
  """
  @spec remove_cells(non_neg_integer(), [Group.cell()]) :: :ok
  def remove_cells(group_id, cells), do: remove_cells(default_server(), group_id, cells)

  @doc false
  @spec remove_cells(server(), non_neg_integer(), [Group.cell()]) :: :ok
  def remove_cells(server, group_id, cells),
    do: GenServer.call(server, {:remove_cells, group_id, cells})

  @doc """
  Removes every skill-unit cell on `map_name` inside `cells` (Ganbantein),
  Land Protector and traps included; a group left without cells is destroyed.

  A caster-following group (a pre-renewal song or dance) is destroyed whole when
  its centre lies inside `cells` and is otherwise left untouched. So is a
  RangedSingleUnit field (Pneuma, pre-renewal Basilica), when its centre cell
  is still laid.
  """
  @spec clear_area(String.t(), [Group.cell()]) :: :ok
  def clear_area(map_name, cells), do: clear_area(default_server(), map_name, cells)

  @doc false
  @spec clear_area(server(), String.t(), [Group.cell()]) :: :ok
  def clear_area(server, map_name, cells),
    do: GenServer.call(server, {:clear_area, map_name, cells})

  @doc "Moves a live group's expiry to `expires_at` (monotonic ms). A no-op for a gone group."
  @spec set_expires_at(non_neg_integer(), integer()) :: :ok
  def set_expires_at(group_id, expires_at),
    do: GenServer.call(default_server(), {:set_expires_at, group_id, expires_at})

  @doc "Runs cleanup and destroys a live group."
  @spec destroy(non_neg_integer()) :: :ok
  def destroy(group_id), do: destroy(default_server(), group_id)

  @doc false
  @spec destroy(server(), non_neg_integer()) :: :ok
  def destroy(server, group_id), do: GenServer.call(server, {:destroy, group_id})

  @doc "Requests group teardown without waiting for the manager (safe inside callbacks)."
  @spec destroy_async(non_neg_integer()) :: :ok
  def destroy_async(group_id), do: destroy_async(default_server(), group_id)

  @doc false
  @spec destroy_async(server(), non_neg_integer()) :: :ok
  def destroy_async(server, group_id), do: GenServer.cast(server, {:destroy, group_id})

  @doc """
  Asks a caster-anchored group to recenter on its caster's new cell.

  Asynchronous, so the moving unit's session never waits on the manager. A
  stale request (group gone, other map, already centered) is a no-op.
  """
  @spec follow_caster(non_neg_integer(), String.t(), Group.cell()) :: :ok
  def follow_caster(group_id, map_name, cell),
    do: follow_caster(default_server(), group_id, map_name, cell)

  @doc false
  @spec follow_caster(server(), non_neg_integer(), String.t(), Group.cell()) :: :ok
  def follow_caster(server, group_id, map_name, cell),
    do: GenServer.cast(server, {:follow_caster, group_id, map_name, cell})

  @doc "Returns a live targetable cell, revalidating it inside the owning manager."
  @spec targetable_cell(server(), non_neg_integer()) :: {:ok, Cell.t()} | {:error, atom()}
  def targetable_cell(server, cell_id), do: GenServer.call(server, {:targetable_cell, cell_id})

  @doc "Applies a basic attack only if the cell remains targetable."
  @spec damage_targetable_cell(server(), non_neg_integer(), pos_integer(), mover()) ::
          {:ok, Cell.t()} | {:destroyed, Cell.t()} | {:error, term()}
  def damage_targetable_cell(server, cell_id, amount, source),
    do: GenServer.call(server, {:damage_targetable_cell, cell_id, amount, source})

  @doc "Publishes an authoritative visible-group snapshot to one observer."
  @spec snapshot_for(integer(), String.t(), integer(), integer(), non_neg_integer()) :: MapSet.t()
  def snapshot_for(observer_id, map_name, x, y, range),
    do: snapshot_for(default_server(), observer_id, map_name, x, y, range)

  @doc false
  @spec snapshot_for(server(), integer(), String.t(), integer(), integer(), non_neg_integer()) ::
          MapSet.t()
  def snapshot_for(server, observer_id, map_name, x, y, range),
    do: GenServer.call(server, {:snapshot_for, observer_id, map_name, x, y, range})

  @doc "Applies one serialized ground-skill visibility diff for an observer."
  @spec sync_view(integer(), Enumerable.t(), Enumerable.t()) :: MapSet.t(non_neg_integer())
  def sync_view(observer_id, enter_ids, leave_ids),
    do: sync_view(default_server(), observer_id, enter_ids, leave_ids)

  @doc false
  @spec sync_view(server(), integer(), Enumerable.t(), Enumerable.t()) ::
          MapSet.t(non_neg_integer())
  def sync_view(server, observer_id, enter_ids, leave_ids),
    do: GenServer.call(server, {:sync_view, observer_id, enter_ids, leave_ids})

  @doc "Drops all tracked skill-unit visibility for one observer."
  @spec clear_observer(integer()) :: :ok
  def clear_observer(observer_id), do: clear_observer(default_server(), observer_id)

  @doc false
  @spec clear_observer(server(), integer()) :: :ok
  def clear_observer(server, observer_id),
    do: GenServer.call(server, {:clear_observer, observer_id})

  @doc "Registers an invisible Water Ball sequence from ordered water-source cells."
  @spec register_water_ball_sequence(Group.t(), [Group.cell()]) ::
          {:ok, Group.t()} | {:error, :no_water_source | term()}
  def register_water_ball_sequence(%Group{} = group, cells),
    do: register_water_ball_sequence(default_server(), group, cells)

  @doc false
  @spec register_water_ball_sequence(server(), Group.t(), [Group.cell()]) ::
          {:ok, Group.t()} | {:error, :no_water_source | term()}
  def register_water_ball_sequence(server, %Group{} = group, cells),
    do: GenServer.call(server, {:register_water_ball_sequence, group, cells})

  @typedoc "A movement event: a unit placed on the footprint."
  @type trigger_callback :: :on_touch

  @typedoc "A cell a mover stands on: `{map_name, x, y}`."
  @type step_cell :: {String.t(), integer(), integer()}

  @doc "Serially invokes a movement callback against the latest live group."
  @spec trigger(non_neg_integer(), mover(), trigger_callback()) :: :ok
  def trigger(group_id, mover, callback), do: trigger(default_server(), group_id, mover, callback)

  @doc false
  @spec trigger(server(), non_neg_integer(), mover(), trigger_callback()) :: :ok
  def trigger(server, group_id, mover, callback) when callback == :on_touch do
    GenServer.call(server, {:trigger, group_id, mover, callback})
  end

  @doc """
  A unit appearing on `cell` without stepping onto it, run as one serial pass
  over the groups there: a dissonant song cell leaves it there and then,
  Spider Web and timer units do nothing, every other group places it
  (`on_touch`, then `onplace`).
  """
  @spec appear(mover(), step_cell()) :: :ok
  def appear(mover, cell), do: appear(default_server(), mover, cell)

  @doc false
  @spec appear(server(), mover(), step_cell()) :: :ok
  def appear(server, mover, cell), do: GenServer.call(server, {:appear, mover, cell})

  @doc """
  A unit removed from play on `cell`, run as one serial pass over the groups
  there with no step bookkeeping: a dissonant song cell leaves it there and
  then, timer units do nothing, every other group runs its leave events
  (`on_out`, then `onleft`).
  """
  @spec remove(mover(), step_cell()) :: :ok
  def remove(mover, cell), do: remove(default_server(), mover, cell)

  @doc false
  @spec remove(server(), mover(), step_cell()) :: :ok
  def remove(server, mover, cell), do: GenServer.call(server, {:remove, mover, cell})

  @doc """
  A step from `old` to `new`, run as one serial pass: every group on the old
  cell leaves the mover (`onout`, remembered per skill), every group on the
  new cell places it (`on_touch`, then `onplace`; a placement forgets one
  remembered entry of its skill), and the fields still remembered run
  `onleft`. A dissonant song cell leaves the mover there and then. The
  handler's `on_out` runs once per footprint stepped off.
  """
  @spec step(mover(), step_cell(), step_cell()) :: :ok
  def step(mover, old, new), do: step(default_server(), mover, old, new)

  @doc false
  @spec step(server(), mover(), step_cell(), step_cell()) :: :ok
  def step(server, mover, old, new), do: GenServer.call(server, {:step, mover, old, new})

  @doc "Processes one cadence tick using the configured clock."
  @spec tick(server()) :: :ok
  def tick(server \\ default_server()), do: GenServer.call(server, :tick)

  @doc false
  @spec tick(server(), integer()) :: :ok
  def tick(server, now) when server == __MODULE__, do: tick(default_server(), now)
  def tick(server, now), do: GenServer.call(server, {:tick, now})

  @impl true
  def init(opts) do
    :ok = Lifecycle.subscribe()
    :ok = Cells.reconcile_indexes()

    state = %{
      clock: Keyword.get(opts, :clock, &__MODULE__.default_clock/0),
      rng: Keyword.get(opts, :rng, &__MODULE__.default_rng/1),
      schedule_tick: Keyword.get(opts, :schedule_tick, &__MODULE__.default_schedule_tick/2),
      tick_interval: Keyword.get(opts, :tick_interval, @tick_interval),
      unit_available?: Keyword.get(opts, :unit_available?, &__MODULE__.default_unit_available?/3),
      ticksets: %{}
    }

    schedule_tick(state)
    Logger.info("Skill.Unit.Manager started with #{state.tick_interval}ms interval")
    {:ok, state}
  end

  @impl true
  def handle_call({:register, group}, _from, state) do
    case Registration.register(group, state.clock.(), state.rng) do
      {:ok, group} ->
        if Storage.get(group.group_id) do
          FieldSupport.place(group, group.cells)
          Publisher.spawn(group)
        end

        {:reply, :ok, state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:reveal_traps, map_name, x, y, range}, _from, state) do
    {:reply, Traps.reveal(map_name, x, y, range), state}
  end

  def handle_call({:reclaim_trap, owner, map_name, x, y}, _from, state) do
    {:reply, Traps.reclaim(owner, map_name, x, y), state}
  end

  def handle_call({:spring_trap, map_name, x, y}, _from, state) do
    {:reply, Traps.spring(map_name, x, y, state.clock.()), state}
  end

  def handle_call({:update_state, group_id, new_state}, _from, state) do
    case Storage.get(group_id) do
      nil ->
        :ok

      %Group{state: current} = group ->
        Storage.update(%{group | state: Map.merge(current, new_state)})
    end

    {:reply, :ok, state}
  end

  def handle_call({:absorb_safetywall_hit, group_id, damage}, _from, state) do
    result = absorb_safetywall_hit_now(group_id, damage)
    {:reply, result, state}
  end

  def handle_call({:remove_cells, group_id, cells}, _from, state) do
    if group = Storage.get(group_id), do: GroupLifecycle.remove_cells(group, MapSet.new(cells))
    {:reply, :ok, state}
  end

  def handle_call({:clear_area, map_name, cells}, _from, state) do
    area = MapSet.new(cells)

    cells
    |> Enum.flat_map(fn {x, y} -> Storage.get_groups_at_cell(map_name, x, y) end)
    |> Enum.uniq_by(& &1.group_id)
    |> Enum.each(fn group ->
      cond do
        Group.follows_caster?(group) and MapSet.member?(area, group.center) ->
          GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)

        Group.follows_caster?(group) ->
          :ok

        GroupLifecycle.ranged_single_unit?(group) ->
          GroupLifecycle.remove_ranged_single_unit(group, area)

        true ->
          GroupLifecycle.remove_cells(group, area)
      end
    end)

    {:reply, :ok, state}
  end

  def handle_call({:set_expires_at, group_id, expires_at}, _from, state) do
    if group = Storage.get(group_id), do: Storage.update(%{group | expires_at: expires_at})
    {:reply, :ok, state}
  end

  def handle_call({:destroy, group_id}, _from, state) do
    if group = Storage.get(group_id),
      do: GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_CANCELED)

    {:reply, :ok, state}
  end

  def handle_call({:targetable_cell, cell_id}, _from, state) do
    {:reply, Cells.fetch_targetable(cell_id), state}
  end

  def handle_call({:damage_targetable_cell, cell_id, amount, source}, _from, state) do
    result =
      with {:ok, _cell} <- Cells.fetch_targetable(cell_id) do
        GroupLifecycle.damage_cell(cell_id, amount, source, :damage)
      end

    {:reply, result, state}
  end

  def handle_call({:snapshot_for, observer_id, map_name, x, y, range}, _from, state) do
    {:reply, Publisher.snapshot_for(observer_id, map_name, x, y, range), state}
  end

  def handle_call({:sync_view, observer_id, enter_ids, leave_ids}, _from, state) do
    {:reply, Publisher.sync_view(observer_id, enter_ids, leave_ids), state}
  end

  def handle_call({:clear_observer, observer_id}, _from, state) do
    :ok = Storage.replace_observer_groups(observer_id, [])
    {:reply, :ok, state}
  end

  def handle_call({:register_water_ball_sequence, group, cells}, _from, state) do
    {:reply, WaterBall.register_sequence(group, cells), state}
  end

  def handle_call({:trigger, group_id, mover, callback}, _from, state) do
    if group = Storage.get(group_id), do: run_trigger(group, mover, callback)
    {:reply, :ok, state}
  end

  def handle_call({:appear, mover, {map_name, x, y}}, _from, state) do
    map_name
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.each(&appear_on(&1, mover, {x, y}))

    {:reply, :ok, state}
  end

  def handle_call({:remove, mover, {map_name, x, y}}, _from, state) do
    map_name
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.each(&remove_from(&1, mover, {x, y}))

    {:reply, :ok, state}
  end

  def handle_call({:step, mover, old, new}, _from, state) do
    run_step(mover, old, new)
    {:reply, :ok, state}
  end

  def handle_call(:tick, _from, state) do
    {:reply, :ok, process_tick(state, state.clock.())}
  end

  def handle_call({:tick, now}, _from, state) do
    {:reply, :ok, process_tick(state, now)}
  end

  @impl true
  def handle_cast({:destroy, group_id}, state) do
    if group = Storage.get(group_id),
      do: GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_CANCELED)

    {:noreply, state}
  end

  def handle_cast({:follow_caster, group_id, map_name, cell}, state) do
    case Storage.get(group_id) do
      %Group{map_name: ^map_name, center: center} = group when center != cell ->
        GroupLifecycle.move(group, cell)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_cast({:displace_cell, cell_id, {x, y, map_name}, destination}, state) do
    with {:ok, %Cell{x: ^x, y: ^y, map_name: ^map_name, group_id: group_id} = cell} <-
           Cells.fetch_targetable(cell_id),
         false <- Cell.knockback_immune?(cell),
         %Group{cells: [{^x, ^y}]} = group <- Storage.get(group_id) do
      GroupLifecycle.move(group, destination)
    end

    {:noreply, state}
  end

  def handle_cast(message, state) do
    Logger.warning("Ignoring unknown skill-unit manager cast: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:unit_lifecycle, %Event{} = event}, state) do
    apply_lifecycle_event(event)
    reset_unit_hit_counters(event)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    state = process_tick(state, state.clock.())
    schedule_tick(state)
    {:noreply, state}
  end

  defp schedule_tick(state) do
    state.schedule_tick.(self(), state.tick_interval)
    :ok
  end

  # Death and leaving the server clear a unit's status data, Storm Gust's hit
  # counter included; a warp keeps it. The manager is the counter's only
  # incrementer, so ordering the reset here keeps both in one mailbox.
  defp reset_unit_hit_counters(%Event{reason: :warp}), do: :ok

  defp reset_unit_hit_counters(%Event{unit_type: unit_type, unit_id: unit_id}),
    do: StatusStorage.reset_storm_gust_counter(unit_type, unit_id)

  defp apply_lifecycle_event(%Event{unit_type: unit_type, unit_id: unit_id} = event) do
    Storage.get_groups_by_caster(unit_type, unit_id)
    |> Enum.each(&apply_lifecycle_event(&1.group_id, :caster, event))

    Storage.get_groups_by_target(unit_type, unit_id)
    |> Enum.each(&apply_lifecycle_event(&1.group_id, :target, event))
  end

  defp apply_lifecycle_event(group_id, relation, event) do
    with %Group{} = group <- Storage.get(group_id),
         true <- affects_group?(event, group) do
      apply_lifecycle_policy(group, relation)
    else
      _ -> :ok
    end
  end

  defp affects_group?(%Event{new_map: nil}, _group), do: true

  defp affects_group?(%Event{old_map: old_map}, %Group{map_name: map_name}) do
    old_map == map_name
  end

  defp apply_lifecycle_policy(%Group{lifecycle_policy: policy} = group, relation) do
    case Map.fetch!(policy, policy_field(relation)) do
      :expire -> GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_LIFECYCLE)
      :skip_action -> :ok
    end
  end

  defp policy_field(:caster), do: :on_caster_loss
  defp policy_field(:target), do: :on_target_loss

  defp process_tick(state, now) do
    state = run_unit_pass(state, now)
    due = Storage.get_due_groups(now)
    expired = Storage.get_expired_groups(now)

    Enum.each(due, &run_interval(&1, now, state.unit_available?))
    Enum.each(expired, &expire_if_live(&1, now, state.unit_available?))
    state
  end

  # Interval fields acting per cell; an expired field is reaped below instead.
  defp run_unit_pass(state, now) do
    fields =
      for %Group{unit_range: range} = group <- Storage.all(),
          is_integer(range) and unit_pass?(group, now),
          {:ok, module} <- [Handler.for_group(group)],
          do: {group, module}

    case fields do
      [] ->
        %{state | ticksets: Map.reject(state.ticksets, fn {_key, next} -> next <= now end)}

      fields ->
        {results, ticksets} =
          UnitTimer.run(
            fields,
            state.ticksets,
            now,
            &Handler.invoke/3,
            &run_manager_command(&1, now),
            &prepare_unit_cell/3
          )

        Enum.each(results, &finish_unit_pass/1)
        %{state | ticksets: ticksets}
    end
  end

  defp prepare_unit_cell(cell, group, now) do
    current = Storage.get_cell(cell.cell_id) || cell

    case TrapCombat.exhaustion(current, group) do
      :none ->
        group

      :expire ->
        GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
        nil

      :used ->
        case Traps.mark_used(group, now) do
          {:ok, used} ->
            used

          {:error, reason} ->
            Handler.log_error(group, :trap_durability, reason)
            GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
            nil
        end
    end
  end

  # A live field acts until it expires; one that strikes on expiry acts only
  # on the pass that finds it expired, and is reaped right after.
  defp unit_pass?(%Group{expires_at: expires_at} = group, now) when is_integer(expires_at) do
    if Group.strikes_on_expiry?(group), do: expires_at <= now, else: expires_at > now
  end

  defp unit_pass?(%Group{}, _now), do: false

  defp finish_unit_pass({group, module, outcome}) do
    case outcome do
      :ok ->
        persist_unit_pass(group, module)

      :expire ->
        if Storage.get(group.group_id), do: GroupLifecycle.cleanup(group, module)

      {:failed, callback, reason} ->
        GroupLifecycle.callback_failed(group, callback, reason, module)
    end
  end

  # A trap sprung during the pass persists through its lifecycle transition,
  # which also republishes its changed view.
  defp persist_unit_pass(%Group{group_id: group_id} = group, module) do
    case Storage.get(group_id) do
      nil ->
        :ok

      ^group ->
        :ok

      %Group{} = stored ->
        case GroupLifecycle.persist_callback_update(stored, group) do
          :ok -> :ok
          {:error, reason} -> GroupLifecycle.callback_failed(stored, :on_unit_hit, reason, module)
        end
    end
  end

  defp run_interval(%Group{} = group, now, unit_available?) do
    case lifecycle_action(group, unit_available?) do
      :continue -> run_sequence_interval(group, now)
      :expire -> GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_LIFECYCLE)
      :skip_action -> Storage.update(%{group | next_tick_at: now + group.interval})
    end
  end

  defp run_sequence_interval(%Group{state: %{water_ball_sequence: true}} = group, now),
    do: WaterBall.run_interval(group, now)

  defp run_sequence_interval(group, now), do: run_interval_callback(group, now)

  defp run_interval_callback(group, now) do
    case Handler.for_group(group) do
      {:ok, module} -> invoke_interval(module, group, now)
      :error -> GroupLifecycle.callback_failed(group, :on_interval, :missing_handler, nil)
    end
  end

  defp lifecycle_action(%Group{} = group, unit_available?) do
    case loss_action(group, :caster, unit_available?) do
      :continue -> loss_action(group, :target, unit_available?)
      action -> action
    end
  end

  defp loss_action(%Group{target_type: nil}, :target, _unit_available?), do: :continue
  defp loss_action(%Group{target_id: nil}, :target, _unit_available?), do: :continue

  defp loss_action(%Group{} = group, relation, unit_available?) do
    {unit_type, unit_id} = unit_identity(group, relation)

    if unit_available?.(unit_type, unit_id, group.map_name) do
      :continue
    else
      Map.fetch!(group.lifecycle_policy, policy_field(relation))
    end
  end

  defp unit_identity(group, :caster), do: {group.caster_type, group.caster_id}
  defp unit_identity(group, :target), do: {group.target_type, group.target_id}

  defp unit_available?(:player, unit_id, map_name) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {_module, %PlayerState{map_name: ^map_name, action_state: action_state}, _pid}} ->
        action_state != :dead

      _other ->
        false
    end
  end

  defp unit_available?(:mob, unit_id, map_name) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, %MobState{map_name: ^map_name, is_dead: false}, _pid}} -> true
      _other -> false
    end
  end

  defp unit_available?(:homunculus, unit_id, map_name) do
    case UnitRegistry.get_unit(:homunculus, unit_id) do
      {:ok, {_module, %{map_name: ^map_name} = state, _pid}} -> Unit.living?(state)
      _other -> false
    end
  end

  defp unit_available?(_unit_type, _unit_id, _map_name), do: false

  @doc """
  The default pass interval: how often every unit cell acts. A unit striking
  faster than this strikes several times per pass.
  """
  @spec tick_interval() :: pos_integer()
  def tick_interval, do: @tick_interval

  @doc false
  @spec default_clock() :: integer()
  def default_clock, do: System.monotonic_time(:millisecond)

  @doc false
  @spec default_rng(pos_integer()) :: non_neg_integer()
  def default_rng(upper), do: :rand.uniform(upper) - 1

  @doc false
  @spec default_schedule_tick(pid(), non_neg_integer()) :: reference()
  def default_schedule_tick(pid, interval), do: Process.send_after(pid, :tick, interval)

  @doc false
  @spec default_unit_available?(atom(), integer(), String.t()) :: boolean()
  def default_unit_available?(unit_type, unit_id, map_name),
    do: unit_available?(unit_type, unit_id, map_name)

  defp invoke_interval(module, group, now) do
    case Handler.invoke(module, :on_interval, [group, now]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        GroupLifecycle.update_after_interval(updated, now, module)

      {:ok, {:ok, %Group{group_id: group_id} = updated, {:remove_cells, cells}}}
      when group_id == group.group_id and is_list(cells) ->
        GroupLifecycle.update_and_drop_cells(updated, cells, now, module)

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        GroupLifecycle.callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, {:expire, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        GroupLifecycle.cleanup(updated, module)

      {:ok, {:expire, %Group{group_id: group_id}}} ->
        GroupLifecycle.callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, result} ->
        GroupLifecycle.callback_failed(group, :on_interval, {:invalid_return, result}, module)

      {:error, reason} ->
        GroupLifecycle.callback_failed(group, :on_interval, reason, module)
    end
  end

  defp expire_if_live(%Group{group_id: group_id}, now, unit_available?) do
    case Storage.get(group_id) do
      %Group{expires_at: expires_at} = group when is_integer(expires_at) and expires_at <= now ->
        Traps.expire_naturally(group, now, unit_available?)

      _group ->
        :ok
    end
  end

  # An appearance never wakes Spider Web; a dissonant song cell leaves the
  # unit whether or not it targets it; a timer unit waits for its timer.
  defp appear_on(%Group{} = group, mover, cell) do
    cond do
      not Traps.triggerable?(group) or not Trigger.acts_on_appearance?(group) -> :ok
      FieldSupport.dissonant?(group, cell) -> FieldSupport.dissonance_step(group, mover)
      Trigger.timer_unit?(group) -> :ok
      true -> run_trigger(group, mover, :on_touch)
    end
  end

  # A unit removed from play (map removal, death) leaves every field on its
  # cell for good: the handler's `on_out`, then the field's `onleft`.
  defp remove_from(%Group{} = group, mover, cell) do
    cond do
      not Traps.triggerable?(group) ->
        :ok

      FieldSupport.dissonant?(group, cell) ->
        FieldSupport.dissonance_step(group, mover)

      Trigger.timer_unit?(group) ->
        :ok

      true ->
        FieldSupport.leave(
          group,
          mover,
          &GroupLifecycle.run_out_callback(group, Handler.or_nil(group), &1)
        )
    end
  end

  # A ground unit acts only on a unit its target check reaches; an invincible
  # player is never reached. The field status follows the handler callback.
  defp run_trigger(%Group{} = group, mover, :on_touch) do
    cond do
      not FieldSupport.target?(group, mover) -> :skipped
      not Traps.triggerable?(group) or suppressed_touch?(group, mover, :on_touch) -> :skipped
      true -> run_live_trigger(group, mover, :on_touch)
    end
  end

  defp run_step(mover, {old_map, old_x, old_y}, {new_map, new_x, new_y} = new) do
    remembered =
      old_map
      |> step_groups(old_x, old_y)
      |> Enum.flat_map(&step_out(&1, mover, {old_x, old_y}, new))

    new_map
    |> step_groups(new_x, new_y)
    |> Enum.reduce(remembered, &step_in(&1, mover, {new_x, new_y}, &2))
    |> Enum.each(fn {_skill_id, group} -> FieldSupport.onleft(group, mover) end)
  end

  defp step_groups(map_name, x, y) do
    map_name
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.filter(&Traps.triggerable?/1)
  end

  # Stepping off a cell: a target leaves it (the handler's `on_out` once the
  # mover is off the whole footprint) and is remembered unless it performs the
  # song; a non-target is remembered only for its own ensemble. A timer unit
  # takes no part.
  defp step_out(%Group{} = group, mover, cell, {new_map, new_x, new_y}) do
    cond do
      FieldSupport.dissonant?(group, cell) ->
        FieldSupport.dissonance_step(group, mover)
        []

      Trigger.timer_unit?(group) ->
        []

      FieldSupport.target?(group, mover) ->
        if new_map != group.map_name or {new_x, new_y} not in group.cells,
          do: GroupLifecycle.run_out_callback(group, Handler.or_nil(group), mover)

        if FieldSupport.onout(group, mover) == :left, do: [{group.skill_id, group}], else: []

      FieldSupport.ensemble_performer?(group, mover) ->
        [{group.skill_id, group}]

      true ->
        []
    end
  end

  # Stepping onto a cell: a placement that ran to its end forgets one
  # remembered entry of the skill, so the mover never leaves a field it is
  # still placed on. Spider Web and timer units take no part.
  defp step_in(%Group{} = group, mover, cell, remembered) do
    cond do
      not Trigger.acts_on_appearance?(group) ->
        remembered

      FieldSupport.dissonant?(group, cell) ->
        FieldSupport.dissonance_step(group, mover)
        remembered

      Trigger.timer_unit?(group) ->
        remembered

      not FieldSupport.target?(group, mover) ->
        if FieldSupport.ensemble_performer?(group, mover),
          do: List.keydelete(remembered, group.skill_id, 0),
          else: remembered

      suppressed_touch?(group, mover, :on_touch) ->
        remembered

      run_live_trigger(group, mover, :on_touch) == :placed ->
        List.keydelete(remembered, group.skill_id, 0)

      true ->
        remembered
    end
  end

  defp run_live_trigger(%Group{} = group, mover, :on_touch) do
    with {:ok, module} <- Handler.for_group(group),
         true <- function_exported?(module, :on_touch, 2) do
      case invoke_trigger(group, mover, :on_touch, module) do
        {:ok, updated} -> FieldSupport.onplace(updated, mover)
        :ended -> :skipped
      end
    else
      _ -> FieldSupport.onplace(group, mover)
    end
  end

  # A magic field's cell left under Land Protector (a RangedSingleUnit field
  # whose centre survived) acts on nobody stepping onto it.
  defp suppressed_touch?(%Group{} = group, {unit_type, unit_id}, :on_touch) do
    with false <- Group.land_protector?(group),
         {:ok, %{damage_kind: :magic}} <- Catalog.by_id(group.skill_id),
         {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id) do
      map_name == group.map_name and Storage.land_protected?(map_name, x, y)
    else
      _acts -> false
    end
  end

  defp invoke_trigger(group, mover, callback, module) do
    case Handler.invoke(module, callback, [group, mover]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        case GroupLifecycle.persist_callback_update(group, updated) do
          :ok ->
            {:ok, updated}

          {:error, reason} ->
            GroupLifecycle.callback_failed(group, callback, reason, module)
            :ended
        end

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        GroupLifecycle.callback_failed(group, callback, {:foreign_group_id, group_id}, module)
        :ended

      {:ok, :expire} ->
        GroupLifecycle.cleanup(group, module)
        :ended

      {:ok, result} ->
        GroupLifecycle.callback_failed(group, callback, {:invalid_return, result}, module)
        :ended

      {:error, reason} ->
        GroupLifecycle.callback_failed(group, callback, reason, module)
        :ended
    end
  end

  # Returns the groups the command changed, as stored; a group whose last cell
  # it removed comes back without cells.
  defp run_manager_command({:spend_traps, map_name, {x, y}, radius}, now),
    do: Traps.spend_in_area(map_name, x, y, radius, now)

  defp run_manager_command({:remove_cells, group_id, cells}, _now) do
    case Storage.get(group_id) do
      nil ->
        []

      %Group{} = live ->
        :ok = GroupLifecycle.remove_cells(live, MapSet.new(cells))
        [Storage.get(group_id) || %{live | cells: []}]
    end
  end

  defp absorb_safetywall_hit_now(group_id, damage) do
    case Storage.get(group_id) do
      nil ->
        :pass

      %Group{skill_id: skill_id} when skill_id != @safetywall_skill_id ->
        :pass

      # A wall with no damage pool (`nil`) blocks purely by hit count.
      %Group{state: %{hits_remaining: hits, shield_hp: shield_hp}} = group ->
        hits_remaining = hits - 1

        if hits_remaining <= 0 or (shield_hp && shield_hp - damage <= 0) do
          GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
          {:block, :remove}
        else
          state = %{
            group.state
            | hits_remaining: hits_remaining,
              shield_hp: shield_hp && shield_hp - damage
          }

          :ok = Storage.update(%{group | state: state})
          {:block, :keep}
        end
    end
  end

  defp default_server, do: ProcessTree.get({__MODULE__, :server}) || __MODULE__
end
