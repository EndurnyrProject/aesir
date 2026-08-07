defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Manager do
  @moduledoc """
  Serializes every ground skill-unit mutation and drives interval/expiry ticks.

  Storage reads remain direct, while registration, callback updates, explicit
  state changes, and teardown pass through this process so the primary row and
  every secondary index change as one ordered operation.
  """

  use GenServer

  require Logger

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.SkillUnitDespawn
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.Net.SkillUnitUpdate
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skill.Unit.View
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @tick_interval 100
  @sprung_trap_lifetime 1_500
  @trap_item_id 1065
  @safetywall_skill_id 12
  @venom_dust_skill_id 140
  @poison_mist_skill_id 8020
  @no_overlap_skill_ids [@safetywall_skill_id, 70, 79, 229]

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
          {:ok, %{group_id: non_neg_integer(), item_id: pos_integer()}} | {:error, atom()}
  def reclaim_trap(owner, map_name, x, y),
    do: reclaim_trap(default_server(), owner, map_name, x, y)

  @doc false
  @spec reclaim_trap(server(), mover(), String.t(), integer(), integer()) ::
          {:ok, %{group_id: non_neg_integer(), item_id: pos_integer()}} | {:error, atom()}
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

  @doc "Asynchronously releases a captured trap only when its link still matches."
  @spec release_trap_link(non_neg_integer(), non_neg_integer()) :: :ok
  def release_trap_link(group_id, link_id),
    do: release_trap_link(default_server(), group_id, link_id)

  @doc false
  @spec release_trap_link(server(), non_neg_integer(), non_neg_integer()) :: :ok
  def release_trap_link(server, group_id, link_id)
      when is_integer(group_id) and group_id >= 0 and is_integer(link_id) and link_id >= 0 do
    GenServer.cast(server, {:release_trap_link, group_id, link_id})
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

  @doc "Runs cleanup and destroys a live group."
  @spec destroy(non_neg_integer()) :: :ok
  def destroy(group_id), do: destroy(default_server(), group_id)

  @doc false
  @spec destroy(server(), non_neg_integer()) :: :ok
  def destroy(server, group_id), do: GenServer.call(server, {:destroy, group_id})

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

  @doc "Serially invokes a movement callback against the latest live group."
  @spec trigger(non_neg_integer(), mover(), :on_touch | :on_out) :: :ok
  def trigger(group_id, mover, callback), do: trigger(default_server(), group_id, mover, callback)

  @doc false
  @spec trigger(server(), non_neg_integer(), mover(), :on_touch | :on_out) :: :ok
  def trigger(server, group_id, mover, callback) when callback in [:on_touch, :on_out] do
    GenServer.call(server, {:trigger, group_id, mover, callback})
  end

  @doc "Reconciles field support for a unit at its current indexed position."
  @spec reconcile_unit(mover()) :: :ok
  def reconcile_unit(mover) do
    case ProcessTree.get({__MODULE__, :server}) || Process.whereis(__MODULE__) do
      nil -> :ok
      server -> reconcile_unit(server, mover)
    end
  end

  @doc false
  @spec reconcile_unit(server(), mover()) :: :ok
  def reconcile_unit(server, mover), do: GenServer.call(server, {:reconcile_unit, mover})

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
    :ok = reconcile_terrain()

    state = %{
      clock: Keyword.get(opts, :clock, fn -> System.monotonic_time(:millisecond) end),
      rng: Keyword.get(opts, :rng, fn upper -> :rand.uniform(upper) - 1 end),
      schedule_tick: Keyword.get(opts, :schedule_tick, &Process.send_after(&1, :tick, &2)),
      tick_interval: Keyword.get(opts, :tick_interval, @tick_interval),
      unit_available?: Keyword.get(opts, :unit_available?, &unit_available?/3)
    }

    schedule_tick(state)
    Logger.info("Skill.Unit.Manager started with #{state.tick_interval}ms interval")
    {:ok, state}
  end

  @impl true
  def handle_call({:register, group}, _from, state) do
    with {:ok, group} <- apply_exclusive_family(group, state.clock.()),
         :ok <- ensure_no_overlap_admission(group),
         {:ok, group} <- add_venom_dust_metadata(group),
         {:ok, group} <- apply_land_protector(group),
         {:ok, group} <- schedule_group(group, state.rng),
         {:ok, group} <- register_group(group) do
      :ok = enforce_instance_limit(group)

      if Storage.get(group.group_id) do
        group
        |> reconcile_group()
        |> publish_spawn()
      end

      {:reply, :ok, state}
    else
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:reveal_traps, map_name, x, y, range}, _from, state) do
    {:reply, reveal_traps_now(map_name, x, y, range), state}
  end

  def handle_call({:reclaim_trap, owner, map_name, x, y}, _from, state) do
    {:reply, reclaim_trap_now(owner, map_name, x, y), state}
  end

  def handle_call({:spring_trap, map_name, x, y}, _from, state) do
    {:reply, spring_trap_now(map_name, x, y, state.clock.()), state}
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
    if group = Storage.get(group_id), do: remove_group_cells(group, MapSet.new(cells))
    {:reply, :ok, state}
  end

  def handle_call({:destroy, group_id}, _from, state) do
    if group = Storage.get(group_id), do: cleanup(group, nil, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
    {:reply, :ok, state}
  end

  def handle_call({:targetable_cell, cell_id}, _from, state) do
    {:reply, fetch_targetable_cell(cell_id), state}
  end

  def handle_call({:damage_targetable_cell, cell_id, amount, source}, _from, state) do
    result =
      with {:ok, _cell} <- fetch_targetable_cell(cell_id) do
        damage_cell_now(cell_id, amount, source, :damage)
      end

    {:reply, result, state}
  end

  def handle_call({:snapshot_for, observer_id, map_name, x, y, range}, _from, state) do
    groups =
      map_name
      |> Storage.get_visible_groups_in_range(x, y, range)
      |> Enum.filter(&(eligible_recipients(&1, [observer_id]) != []))

    snapshot =
      groups
      |> Enum.map(&{&1, Storage.get_cells_by_group(&1.group_id)})
      |> View.snapshot(ServerTick.now())

    Broadcast.to_player(observer_id, snapshot)
    :ok = Storage.replace_observer_groups(observer_id, Enum.map(groups, & &1.group_id))
    {:reply, MapSet.new(groups, & &1.group_id), state}
  end

  def handle_call({:sync_view, observer_id, enter_ids, leave_ids}, _from, state) do
    {:reply, sync_observer_view(observer_id, enter_ids, leave_ids), state}
  end

  def handle_call({:clear_observer, observer_id}, _from, state) do
    :ok = Storage.replace_observer_groups(observer_id, [])
    {:reply, :ok, state}
  end

  def handle_call({:register_water_ball_sequence, group, cells}, _from, state) do
    result = register_water_ball_sequence_now(group, cells)
    {:reply, result, state}
  end

  def handle_call({:trigger, group_id, mover, callback}, _from, state) do
    if group = Storage.get(group_id), do: run_trigger(group, mover, callback, state.clock.())
    {:reply, :ok, state}
  end

  def handle_call({:reconcile_unit, mover}, _from, state) do
    reconcile_unit_support(mover)
    {:reply, :ok, state}
  end

  def handle_call(:tick, _from, state) do
    process_tick(state.clock.(), state.unit_available?)
    {:reply, :ok, state}
  end

  def handle_call({:tick, now}, _from, state) do
    process_tick(now, state.unit_available?)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:release_trap_link, group_id, link_id}, state) do
    release_trap_link_now(group_id, link_id)
    {:noreply, state}
  end

  def handle_cast(message, state) do
    Logger.warning("Ignoring unknown skill-unit manager cast: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:unit_lifecycle, %Event{} = event}, state) do
    apply_lifecycle_event(event)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    process_tick(state.clock.(), state.unit_available?)
    schedule_tick(state)
    {:noreply, state}
  end

  defp schedule_tick(state) do
    state.schedule_tick.(self(), state.tick_interval)
    :ok
  end

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
      :expire -> cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_LIFECYCLE)
      :skip_action -> :ok
    end
  end

  defp policy_field(:caster), do: :on_caster_loss
  defp policy_field(:target), do: :on_target_loss

  defp process_tick(now, unit_available?) do
    due = Storage.get_due_groups(now)
    expired = Storage.get_expired_groups(now)

    Enum.each(due, &run_interval(&1, now, unit_available?))
    Enum.each(expired, &expire_if_live(&1, now, unit_available?))
  end

  defp run_interval(%Group{} = group, now, unit_available?) do
    group = reconcile_group(group)

    case lifecycle_action(group, unit_available?) do
      :continue -> run_sequence_interval(group, now)
      :expire -> cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_LIFECYCLE)
      :skip_action -> Storage.update(%{group | next_tick_at: now + group.interval})
    end
  end

  defp run_sequence_interval(%Group{state: %{water_ball_sequence: true}} = group, now) do
    if Storage.get_cells_by_group(group.group_id) == [] do
      cleanup(group)
    else
      dispatch_sequence_interval(group, now)
    end
  end

  defp run_sequence_interval(group, now), do: run_interval_callback(group, now)

  defp dispatch_sequence_interval(group, now) do
    case handler_for(group) do
      {:ok, module} -> invoke_sequence_interval(module, group, now)
      :error -> callback_failed(group, :on_interval, :missing_handler, nil)
    end
  end

  defp invoke_sequence_interval(module, group, now) do
    case invoke(module, :on_interval, [group, now]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        advance_sequence(updated, now, module)

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, {:expire, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        cleanup(updated, module)

      {:ok, {:expire, %Group{group_id: group_id}}} ->
        callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, result} ->
        callback_failed(group, :on_interval, {:invalid_return, result}, module)

      {:error, reason} ->
        callback_failed(group, :on_interval, reason, module)
    end
  end

  defp advance_sequence(%Group{state: %{water_ball_fired: false}} = group, now, _module) do
    Storage.update(%{group | next_tick_at: now + group.interval})
  end

  defp advance_sequence(group, now, module) do
    case claim_next_sequence_cell(group) do
      {:ok, group} -> update_after_interval(group, now, module)
      :empty -> cleanup(group, module)
    end
  end

  defp run_interval_callback(group, now) do
    case handler_for(group) do
      {:ok, module} -> invoke_interval(module, group, now)
      :error -> callback_failed(group, :on_interval, :missing_handler, nil)
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

  defp invoke_interval(module, group, now) do
    case invoke(module, :on_interval, [group, now]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        update_after_interval(updated, now, module)

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, {:expire, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        cleanup(updated, module)

      {:ok, {:expire, %Group{group_id: group_id}}} ->
        callback_failed(group, :on_interval, {:foreign_group_id, group_id}, module)

      {:ok, result} ->
        callback_failed(group, :on_interval, {:invalid_return, result}, module)

      {:error, reason} ->
        callback_failed(group, :on_interval, reason, module)
    end
  end

  defp expire_if_live(%Group{group_id: group_id}, now, unit_available?) do
    case Storage.get(group_id) do
      %Group{expires_at: expires_at} = group when is_integer(expires_at) and expires_at <= now ->
        expire_naturally(group, now, unit_available?)

      _group ->
        :ok
    end
  end

  defp run_trigger(%Group{} = group, mover, callback, now) do
    if triggerable?(group) do
      case handler_for(group) do
        {:ok, module} ->
          run_callback_trigger(group, mover, callback, module, now)

        _ ->
          apply_field_support_action(group, mover, callback)
      end
    end
  end

  defp run_callback_trigger(group, mover, callback, module, now) do
    if function_exported?(module, callback, 2) do
      invoke_trigger(group, mover, callback, module, now)
    else
      apply_field_support_action(group, mover, callback)
    end
  end

  defp invoke_trigger(group, mover, callback, module, now) do
    case invoke(module, callback, [group, mover]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        case persist_callback_update(group, updated) do
          :ok -> apply_field_support_action(updated, mover, callback)
          {:error, reason} -> callback_failed(group, callback, reason, module)
        end

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        callback_failed(group, callback, {:foreign_group_id, group_id}, module)

      {:ok, :expire} ->
        expire_from_trigger(group, module, now)

      {:ok, {:expire, commands}} when is_list(commands) ->
        expire_from_trigger(group, module, now)
        Enum.each(commands, &run_manager_command(&1, now))

      {:ok, result} ->
        callback_failed(group, callback, {:invalid_return, result}, module)

      {:error, reason} ->
        callback_failed(group, callback, reason, module)
    end
  end

  defp run_manager_command({:spend_traps, map_name, {x, y}, radius}, now) do
    map_name
    |> groups_in_area(x, y, radius)
    |> Enum.each(&spend_trap(&1, now))
  end

  defp spend_trap(%Group{} = group, now) do
    case trap_state(group) do
      {:ok, %TrapState{phase: :armed, claymore_spendable?: true}} ->
        used = transition_trap(group, :used, now + @sprung_trap_lifetime)

        case persist_trap_update(group, used) do
          :ok -> :ok
          {:error, reason} -> log_spend_trap_failure(group, reason)
        end

      _ineligible ->
        :ok
    end
  end

  defp log_spend_trap_failure(group, reason) do
    Logger.error(
      "Skill.Unit.Manager spend_traps failed group_id=#{group.group_id}: #{inspect(reason)}"
    )
  end

  defp apply_field_support_action(%Group{} = group, {unit_type, unit_id}, :on_touch) do
    with {:ok, spec} <- field_support_spec(group) do
      if living_combat_unit?({unit_type, unit_id}) and
           supports_target?(spec, {unit_type, unit_id}) do
        FieldSupport.acquire(
          unit_type,
          unit_id,
          spec.status_type,
          group.group_id,
          params_for(spec, unit_type, unit_id)
        )
        |> log_field_support_failure(group, :acquire)
      else
        FieldSupport.release(unit_type, unit_id, spec.status_type, group.group_id)
        |> log_field_support_failure(group, :release)
      end
    end

    :ok
  end

  defp apply_field_support_action(%Group{} = group, {unit_type, unit_id}, :on_out) do
    with {:ok, spec} <- field_support_spec(group) do
      FieldSupport.release(unit_type, unit_id, spec.status_type, group.group_id)
      |> log_field_support_failure(group, :release)
    end

    :ok
  end

  defp apply_field_support_action(_group, _mover, _callback), do: :ok

  defp log_field_support_failure({:error, reason} = result, group, action) do
    Logger.error(
      "Skill.Unit.Manager field_support=#{action} failed skill=#{group.skill_name} " <>
        "group_id=#{group.group_id}: #{inspect(reason)}"
    )

    result
  end

  defp log_field_support_failure(result, _group, _action), do: result

  defp release_trap_link_now(group_id, link_id) do
    case Storage.get(group_id) do
      %Group{state: %{trap: %TrapState{phase: :captured, link_id: ^link_id}}} = group ->
        cleanup(group)

      _stale_or_absent ->
        :ok
    end
  end

  defp cleanup(%Group{} = group) do
    module =
      case handler_for(group) do
        {:ok, handler} -> handler
        :error -> nil
      end

    cleanup(group, module, :SKILL_UNIT_DESPAWN_REASON_EXPIRED)
  end

  defp cleanup_with_reason(%Group{} = group, despawn_reason) do
    module =
      case handler_for(group) do
        {:ok, handler} -> handler
        :error -> nil
      end

    cleanup(group, module, despawn_reason)
  end

  defp cleanup(%Group{} = group, module) do
    cleanup(group, module, :SKILL_UNIT_DESPAWN_REASON_EXPIRED)
  end

  defp cleanup(%Group{group_id: group_id} = group, module, despawn_reason) do
    FieldSupport.release_group(group_id)
    cells = Storage.get_cells_by_group(group_id)
    Enum.each(cells, &remove_cell_indexes/1)

    if module && function_exported?(module, :on_expire, 1) do
      case invoke(module, :on_expire, [group]) do
        {:ok, :ok} -> :ok
        {:ok, result} -> log_callback_error(group, :on_expire, {:invalid_return, result})
        {:error, reason} -> log_callback_error(group, :on_expire, reason)
      end
    end

    Storage.delete(group_id)
    publish_group_despawn(group, Enum.map(cells, & &1.cell_id), despawn_reason)
  end

  # Per-caster family exclusivity (rAthena skill_unitsetting,
  # src/map/skill.cpp:5883-5907): placing a member of an exclusive family clears
  # the caster's existing member first, and only the caster's - other casters'
  # fields are untouched. A swap between two groups that both opt into
  # inherit_family_duration carries the replaced group's *remaining* duration, so
  # recasting never refreshes it.
  defp apply_exclusive_family(%Group{lifecycle_policy: %{exclusive_family: nil}} = group, _now),
    do: {:ok, group}

  defp apply_exclusive_family(%Group{} = group, now) do
    case family_groups(group) do
      [] ->
        {:ok, group}

      [replaced | _] = groups ->
        Enum.each(groups, &cleanup_with_reason(&1, :SKILL_UNIT_DESPAWN_REASON_CANCELED))
        {:ok, inherit_family_duration(group, replaced, now)}
    end
  end

  defp ensure_no_overlap_admission(%Group{skill_id: skill_id} = group)
       when skill_id in @no_overlap_skill_ids do
    overlap? =
      Enum.any?(group.cells, fn {x, y} ->
        group.map_name
        |> Storage.get_groups_at_cell(x, y)
        |> Enum.any?(fn existing ->
          existing.skill_id == skill_id and existing.group_id != group.group_id
        end)
      end)

    if overlap?, do: {:error, overlap_error(skill_id)}, else: :ok
  end

  defp ensure_no_overlap_admission(%Group{skill_id: @venom_dust_skill_id} = group) do
    overlap? =
      Enum.any?(group.cells, fn {x, y} ->
        group.map_name
        |> Storage.get_groups_at_cell(x, y)
        |> Enum.any?(&venom_dust_blocker?(&1, group))
      end)

    if overlap?, do: {:error, :skill_unit_overlap}, else: :ok
  end

  defp ensure_no_overlap_admission(%Group{}), do: :ok

  defp venom_dust_blocker?(%Group{group_id: group_id}, %Group{group_id: group_id}), do: false

  defp venom_dust_blocker?(%Group{skill_id: skill_id}, _group)
       when skill_id in [@venom_dust_skill_id, @poison_mist_skill_id],
       do: true

  defp venom_dust_blocker?(%Group{state: %{trap: %TrapState{}}}, _group), do: true
  defp venom_dust_blocker?(%Group{}, _group), do: false

  defp add_venom_dust_metadata(%Group{skill_id: @venom_dust_skill_id} = group),
    do: {:ok, %{group | state: Map.put(group.state, :removed_by_fire_rain, true)}}

  defp add_venom_dust_metadata(%Group{} = group), do: {:ok, group}

  defp overlap_error(@safetywall_skill_id), do: :safetywall_overlap
  defp overlap_error(_skill_id), do: :skill_unit_overlap

  defp absorb_safetywall_hit_now(group_id, damage) do
    case Storage.get(group_id) do
      nil ->
        :pass

      %Group{skill_id: skill_id} when skill_id != @safetywall_skill_id ->
        :pass

      %Group{state: %{hits_remaining: hits, shield_hp: shield_hp}} = group ->
        hits_remaining = hits - 1
        remaining_hp = shield_hp - damage

        if hits_remaining <= 0 or remaining_hp <= 0 do
          cleanup(group, nil, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
          {:block, :remove}
        else
          state = %{group.state | hits_remaining: hits_remaining, shield_hp: remaining_hp}
          :ok = Storage.update(%{group | state: state})
          {:block, :keep}
        end
    end
  end

  defp family_groups(%Group{lifecycle_policy: %{exclusive_family: family}} = group) do
    group.caster_type
    |> Storage.get_groups_by_caster(group.caster_id)
    |> Enum.filter(
      &(&1.group_id != group.group_id and &1.lifecycle_policy.exclusive_family == family)
    )
    |> Enum.sort_by(&{&1.created_at, &1.group_id})
  end

  defp inherit_family_duration(
         %Group{lifecycle_policy: %{inherit_family_duration: true}} = group,
         %Group{lifecycle_policy: %{inherit_family_duration: true}, expires_at: expires_at},
         now
       )
       when expires_at > now,
       do: %{group | expires_at: expires_at}

  defp inherit_family_duration(%Group{} = group, %Group{}, _now), do: group

  # Land Protector's central placement rules (rAthena skill_cell_overlap /
  # skill_unitsetting): a Land Protector group destroys overlapping foreign
  # cells per cell (mutually with an existing Land Protector), and any other
  # placement drops candidate cells that fall on a Land Protector. A group
  # reduced to zero cells fails registration with `:land_protector`.
  defp apply_land_protector(%Group{} = group) do
    cond do
      Group.land_protector?(group) -> sweep_protected_overlap(group)
      Group.ignores_land_protector?(group) -> {:ok, group}
      true -> drop_protected_cells(group)
    end
  end

  defp drop_protected_cells(%Group{cells: []} = group), do: {:ok, group}

  defp drop_protected_cells(%Group{} = group) do
    case Enum.reject(group.cells, fn {x, y} -> Storage.land_protected?(group.map_name, x, y) end) do
      [] -> {:error, :land_protector}
      cells -> {:ok, %{group | cells: cells}}
    end
  end

  defp sweep_protected_overlap(%Group{} = group) do
    {kept, removals} =
      Enum.reduce(group.cells, {[], %{}}, fn {x, y} = cell, {kept, removals} ->
        overlapping =
          group.map_name
          |> Storage.get_groups_at_cell(x, y)
          |> Enum.reject(&Group.ignores_land_protector?/1)

        removals =
          Enum.reduce(overlapping, removals, fn victim, acc ->
            Map.update(acc, victim.group_id, [cell], &[cell | &1])
          end)

        if Enum.any?(overlapping, &Group.land_protector?/1),
          do: {kept, removals},
          else: {[cell | kept], removals}
      end)

    Enum.each(removals, fn {victim_id, cells} ->
      if victim = Storage.get(victim_id), do: remove_group_cells(victim, MapSet.new(cells))
    end)

    case kept do
      [] -> {:error, :land_protector}
      kept -> {:ok, %{group | cells: Enum.reverse(kept)}}
    end
  end

  defp remove_group_cells(%Group{} = group, coordinates) do
    case Enum.split_with(group.cells, &MapSet.member?(coordinates, &1)) do
      {[], _survivors} -> :ok
      {_removed, []} -> cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
      {removed, _survivors} -> shrink_group(group, removed)
    end
  end

  defp shrink_group(%Group{} = group, removed) do
    coordinates = MapSet.new(removed)

    cells =
      group.group_id
      |> Storage.get_cells_by_group()
      |> Enum.filter(&MapSet.member?(coordinates, {&1.x, &1.y}))

    Enum.each(cells, &remove_cell/1)

    group
    |> Storage.remove_cells(removed)
    |> reconcile_group()

    publish_cells_despawn(group, Enum.map(cells, & &1.cell_id))
  end

  defp damage_cell_now(_cell_id, amount, _source, _reason)
       when not is_integer(amount) or amount <= 0,
       do: {:error, :invalid_damage}

  defp damage_cell_now(cell_id, amount, nil, reason),
    do: damage_cell_now_valid(cell_id, amount, nil, reason)

  defp damage_cell_now(cell_id, amount, {source_type, source_id} = source, reason)
       when source_type in [:player, :mob, :homunculus, :npc] and is_integer(source_id) and
              source_id >= 0 do
    damage_cell_now_valid(cell_id, amount, source, reason)
  end

  defp damage_cell_now(_cell_id, _amount, _source, _reason), do: {:error, :invalid_source}

  defp damage_cell_now_valid(cell_id, amount, source, reason) do
    case Storage.get_cell(cell_id) do
      nil ->
        {:error, :not_found}

      %Cell{max_hp: 0} ->
        {:error, :not_destructible}

      %Cell{hp: hp} = cell when amount < hp ->
        updated = %{cell | hp: hp - amount}
        :ok = Storage.update_cell(updated)
        publish_update(updated, -amount, source, reason)
        {:ok, updated}

      %Cell{hp: hp} = cell ->
        updated = %{cell | hp: 0}
        :ok = remove_cell(cell)
        publish_update(updated, -hp, source, reason)
        publish_despawn(cell, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
        expire_if_empty(cell.group_id)
        {:destroyed, cell}
    end
  end

  # Destroying a group's last cell must expire the group immediately, matching
  # the structural-removal path (`remove_group_cells`); otherwise the empty
  # group lingers until the next interval tick reaps it.
  defp expire_if_empty(group_id) do
    with [] <- Storage.get_cells_by_group(group_id),
         %Group{} = group <- Storage.get(group_id) do
      cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
    else
      _ -> :ok
    end
  end

  defp fetch_targetable_cell(cell_id) do
    case Storage.get_cell(cell_id) do
      %Cell{} = cell when cell.hp > 0 ->
        if Cell.flag?(cell, :targetable), do: {:ok, cell}, else: {:error, :not_targetable}

      _ ->
        {:error, :not_found}
    end
  end

  defp remove_cell(%Cell{} = cell) do
    :ok = remove_cell_indexes(cell)
    :ok = Storage.delete_cell(cell.cell_id)
  end

  defp remove_cell_indexes(%Cell{} = cell) do
    :ok = remove_terrain(cell)
    :ok = remove_target(cell)
  end

  defp publish_spawn(%Group{visibility: :none}), do: :ok

  defp publish_spawn(%Group{visibility: :public} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    {x, y} = group.center
    publish(group.map_name, x, y, packet)
  end

  defp publish_spawn(%Group{visibility: :party_only} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    publish_to_eligible_players(group, packet, true)
  end

  defp publish_tracked_spawn(%Group{visibility: :none}), do: :ok

  defp publish_tracked_spawn(%Group{visibility: :public} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    {x, y} = group.center
    :ok = publish(group.map_name, x, y, packet)
    Enum.each(players_in_range(group), &Storage.add_observer_group(&1, group.group_id))
    :ok
  end

  defp publish_tracked_spawn(%Group{visibility: :party_only} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}
    publish_to_eligible_players(group, packet, true)
  end

  defp publish_update(%Cell{} = cell, hp_delta, source, reason) do
    case Storage.get(cell.group_id) do
      %Group{} = group ->
        {source_type, source_id} = source_fields(source)

        packet = %SkillUnitUpdate{
          group_id: group.group_id,
          cell_id: cell.cell_id,
          hp: cell.hp,
          max_hp: cell.max_hp,
          hp_delta: hp_delta,
          source_type: source_type,
          source_id: source_id,
          reason: update_reason(reason),
          server_tick: ServerTick.now()
        }

        publish_by_visibility(group, cell.x, cell.y, packet)

      _ ->
        :ok
    end
  end

  defp publish_despawn(%Cell{} = cell, reason) do
    case Storage.get(cell.group_id) do
      %Group{} = group ->
        packet = %SkillUnitDespawn{
          group_id: cell.group_id,
          cell_ids: [cell.cell_id],
          reason: reason,
          server_tick: ServerTick.now()
        }

        publish_by_visibility(group, cell.x, cell.y, packet)

      _ ->
        :ok
    end
  end

  defp publish_cells_despawn(%Group{} = group, cell_ids) do
    if cell_ids != [] do
      packet = %SkillUnitDespawn{
        group_id: group.group_id,
        cell_ids: Enum.sort(cell_ids),
        reason: :SKILL_UNIT_DESPAWN_REASON_DESTROYED,
        server_tick: ServerTick.now()
      }

      {x, y} = group.center
      publish_by_visibility(group, x, y, packet)
    end

    :ok
  end

  defp publish_group_despawn(%Group{} = group, cell_ids, reason) do
    packet = %SkillUnitDespawn{
      group_id: group.group_id,
      cell_ids: Enum.sort(cell_ids),
      reason: reason,
      server_tick: ServerTick.now()
    }

    observers = Storage.take_group_observers(group.group_id)
    in_range = players_in_range(group)

    case group.visibility do
      :none ->
        :ok

      :public ->
        {x, y} = group.center
        :ok = publish(group.map_name, x, y, packet)

        observers
        |> Enum.uniq()
        |> Kernel.--(in_range)
        |> Enum.each(&Broadcast.to_player(&1, packet))

      :party_only ->
        group
        |> eligible_recipients(in_range)
        |> Enum.concat(observers)
        |> Enum.uniq()
        |> Enum.each(&Broadcast.to_player(&1, packet))
    end

    :ok
  end

  defp publish(map_name, x, y, packet),
    do: Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet)

  defp sync_observer_view(observer_id, enter_ids, leave_ids) do
    leave_ids = leave_ids |> MapSet.new() |> MapSet.to_list() |> Enum.sort()

    enter_ids =
      enter_ids
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(leave_ids))
      |> MapSet.to_list()
      |> Enum.sort()

    observer_groups = Storage.get_observer_groups(observer_id)

    Enum.each(enter_ids, fn group_id ->
      if not MapSet.member?(observer_groups, group_id),
        do: enter_observer_view(observer_id, group_id)
    end)

    Enum.each(leave_ids, fn group_id ->
      if MapSet.member?(observer_groups, group_id), do: leave_observer_view(observer_id, group_id)
    end)

    Storage.get_observer_groups(observer_id)
  end

  defp enter_observer_view(observer_id, group_id) do
    case Storage.get(group_id) do
      %Group{} = group ->
        if eligible_recipients(group, [observer_id]) != [] do
          packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group_id))}
          Broadcast.to_player(observer_id, packet)
          Storage.add_observer_group(observer_id, group_id)
        end

      _ ->
        :ok
    end
  end

  defp leave_observer_view(observer_id, group_id) do
    case Storage.get(group_id) do
      %Group{} = group ->
        if Group.materialized?(group) do
          cell_ids =
            group_id
            |> Storage.get_cells_by_group()
            |> Enum.map(& &1.cell_id)
            |> Enum.sort()

          Broadcast.to_player(observer_id, %SkillUnitDespawn{
            group_id: group_id,
            cell_ids: cell_ids,
            reason: :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW,
            server_tick: ServerTick.now()
          })
        end

      _ ->
        :ok
    end

    Storage.remove_observer_group(observer_id, group_id)
  end

  defp publish_by_visibility(%Group{visibility: :none}, _x, _y, _packet), do: :ok

  defp publish_by_visibility(%Group{visibility: :public} = group, x, y, packet),
    do: publish(group.map_name, x, y, packet)

  defp publish_by_visibility(%Group{visibility: :party_only} = group, x, y, packet) do
    group.map_name
    |> SpatialIndex.get_players_in_range(x, y, Config.view_range())
    |> then(&eligible_recipients(group, &1))
    |> Enum.each(&Broadcast.to_player(&1, packet))
  end

  defp publish_to_eligible_players(%Group{} = group, packet, track?) do
    group
    |> players_in_range()
    |> then(&eligible_recipients(group, &1))
    |> Enum.each(fn player_id ->
      Broadcast.to_player(player_id, packet)
      if track?, do: Storage.add_observer_group(player_id, group.group_id)
    end)

    :ok
  end

  defp players_in_range(%Group{map_name: map_name, center: {x, y}}) do
    SpatialIndex.get_players_in_range(map_name, x, y, Config.view_range())
  end

  defp eligible_recipients(%Group{visibility: :public}, player_ids), do: player_ids
  defp eligible_recipients(%Group{visibility: :none}, _player_ids), do: []

  defp eligible_recipients(%Group{visibility: :party_only} = group, player_ids) do
    player_ids
    |> Enum.uniq()
    |> Enum.filter(fn player_id ->
      observer_party_id =
        case UnitRegistry.get_unit(:player, player_id) do
          {:ok, {_module, %PlayerState{party_id: party_id}, _pid}} -> party_id
          {:error, :not_found} -> nil
        end

      Group.visible_to?(group, player_id, observer_party_id)
    end)
  end

  defp source_fields({:player, source_id}), do: {:SKILL_UNIT_OWNER_TYPE_PLAYER, source_id}

  defp source_fields({:homunculus, world_gid}) do
    case UnitRegistry.get_unit(:homunculus, world_gid) do
      {:ok, {_module, %HomunculusState{owner_character_id: owner_id}, _pid}} ->
        {:SKILL_UNIT_OWNER_TYPE_PLAYER, owner_id}

      {:error, :not_found} ->
        raise ArgumentError, "Homunculus skill-unit damage source unavailable"
    end
  end

  defp source_fields({:mob, source_id}), do: {:SKILL_UNIT_OWNER_TYPE_MOB, source_id}
  defp source_fields({:npc, source_id}), do: {:SKILL_UNIT_OWNER_TYPE_NPC, source_id}
  defp source_fields(nil), do: {:SKILL_UNIT_OWNER_TYPE_UNSPECIFIED, 0}
  defp update_reason(:damage), do: :SKILL_UNIT_UPDATE_REASON_DAMAGE
  defp update_reason(:decay), do: :SKILL_UNIT_UPDATE_REASON_DECAY

  defp triggerable?(%Group{} = group) do
    case trap_state(group) do
      {:ok, %TrapState{phase: :armed}} ->
        true

      {:ok, %TrapState{}} ->
        false

      {:error, :unsupported_trap} ->
        true

      {:error, :invalid_trap_state} ->
        Logger.error("Skill.Unit.Manager rejected invalid trap state group_id=#{group.group_id}")
        false
    end
  end

  defp expire_from_trigger(%Group{} = group, module, now) do
    case trap_state(group) do
      {:ok, %TrapState{phase: :armed}} ->
        used = transition_trap(group, :used, now + @sprung_trap_lifetime)

        case persist_trap_update(group, used) do
          :ok -> :ok
          {:error, reason} -> callback_failed(group, :on_touch, reason, module)
        end

      _non_trap ->
        cleanup(group, module)
    end
  end

  defp persist_callback_update(%Group{} = original, %Group{} = updated) do
    case {trap_state(original), trap_state(updated)} do
      {{:ok, %TrapState{}}, {:ok, %TrapState{}}} -> persist_trap_update(original, updated)
      {{:error, :unsupported_trap}, {:error, :unsupported_trap}} -> Storage.update(updated)
      _invalid -> {:error, :invalid_trap_state}
    end
  end

  defp persist_trap_update(%Group{} = original, %Group{} = updated) do
    with {:ok, %TrapState{}} <- trap_state(updated) do
      case {Group.materialized?(original), Group.materialized?(updated)} do
        {false, false} ->
          Storage.update(updated)

        {false, true} ->
          materialize_trap_update(original, updated)

        {true, true} ->
          persist_visible_trap_update(original, updated)

        {true, false} ->
          {:error, :invalid_trap_transition}
      end
    end
  end

  defp materialize_trap_update(%Group{} = original, %Group{} = updated) do
    case Storage.get_cells_by_group(original.group_id) do
      [] ->
        :ok = Storage.update(updated)

        case materialize_visible_cells(updated, []) do
          {:ok, _cells} ->
            updated |> reconcile_group() |> publish_tracked_spawn()

          {:error, _reason} = error ->
            rollback_trap_materialization(original)
            error
        end

      [_cell | _cells] ->
        {:error, :already_materialized}
    end
  end

  defp persist_visible_trap_update(%Group{} = original, %Group{} = updated) do
    case Storage.get_cells_by_group(original.group_id) do
      [] ->
        {:error, :not_materialized}

      cells ->
        :ok = Storage.update(updated)

        if trap_view_changed?(original, updated) do
          publish_trap_replacement(updated, cells)
        end

        :ok
    end
  end

  defp trap_view_changed?(original, updated) do
    original.expires_at != updated.expires_at or
      original.state.trap.phase != updated.state.trap.phase
  end

  defp publish_trap_replacement(%Group{} = group, cells) do
    cell_ids = cells |> Enum.map(& &1.cell_id) |> Enum.sort()

    despawn = %SkillUnitDespawn{
      group_id: group.group_id,
      cell_ids: cell_ids,
      reason: :SKILL_UNIT_DESPAWN_REASON_DESTROYED,
      server_tick: ServerTick.now()
    }

    spawn = %SkillUnitSpawn{group: View.group(group, cells)}
    {x, y} = group.center
    observers = Storage.take_group_observers(group.group_id)
    in_range = SpatialIndex.get_players_in_range(group.map_name, x, y, Config.view_range())

    case group.visibility do
      :none ->
        :ok

      :public ->
        :ok = publish(group.map_name, x, y, despawn)
        :ok = publish(group.map_name, x, y, spawn)

        observers
        |> Enum.uniq()
        |> Kernel.--(in_range)
        |> Enum.each(fn player_id ->
          Broadcast.to_player(player_id, despawn)
          Broadcast.to_player(player_id, spawn)
        end)

        Enum.each(in_range, &Storage.add_observer_group(&1, group.group_id))

      :party_only ->
        eligible = eligible_recipients(group, in_range)

        observers
        |> Enum.reject(&(&1 in eligible))
        |> Enum.uniq()
        |> Enum.each(&Broadcast.to_player(&1, despawn))

        Enum.each(eligible, fn player_id ->
          Broadcast.to_player(player_id, despawn)
          Broadcast.to_player(player_id, spawn)
          Storage.add_observer_group(player_id, group.group_id)
        end)
    end

    :ok
  end

  defp transition_trap(%Group{state: %{trap: %TrapState{} = trap}} = group, phase, expires_at) do
    %{group | expires_at: expires_at, state: %{group.state | trap: %{trap | phase: phase}}}
  end

  defp expire_naturally(%Group{} = group, now, unit_available?) do
    case trap_state(group) do
      {:ok, %TrapState{phase: :armed, natural_expiry: :become_used}} ->
        used = transition_trap(group, :used, now + @sprung_trap_lifetime)

        :ok = log_natural_expiry_callback_failure(run_natural_expiry_callback(group), group)

        case persist_trap_update(group, used) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Skill.Unit.Manager natural trap transition failed group_id=#{group.group_id}: #{inspect(reason)}"
            )

            cleanup(group)
        end

      {:ok, %TrapState{phase: :armed} = trap} ->
        maybe_drop_expired_trap(group, trap, unit_available?)
        cleanup(group)

      {:ok, %TrapState{}} ->
        cleanup(group)

      {:error, :unsupported_trap} ->
        cleanup(group)

      {:error, :invalid_trap_state} ->
        Logger.error("Skill.Unit.Manager expiring invalid trap state group_id=#{group.group_id}")
        cleanup(group)
    end
  end

  defp run_natural_expiry_callback(%Group{} = group) do
    case handler_for(group) do
      {:ok, module} -> invoke_natural_expiry_callback(module, group)
      :error -> :ok
    end
  end

  defp log_natural_expiry_callback_failure(:ok, _group), do: :ok

  defp log_natural_expiry_callback_failure({:error, reason}, group) do
    log_callback_error(group, :on_natural_expiry, reason)
  end

  defp invoke_natural_expiry_callback(module, group) do
    if function_exported?(module, :on_natural_expiry, 1) do
      case invoke(module, :on_natural_expiry, [group]) do
        {:ok, :ok} -> :ok
        {:ok, {:error, reason}} -> {:error, {:returned_error, reason}}
        {:ok, result} -> {:error, {:invalid_natural_expiry_return, result}}
        {:error, reason} -> {:error, {:natural_expiry_callback_failed, reason}}
      end
    else
      :ok
    end
  end

  defp maybe_drop_expired_trap(
         %Group{caster_type: :player, caster_id: caster_id} = group,
         %TrapState{return_item_on_expiry?: true, reclaim_item_id: item_id},
         unit_available?
       )
       when is_integer(item_id) and item_id > 0 do
    if unit_available?.(:player, caster_id, group.map_name) do
      {x, y} = group.center
      Coordinator.drop_items(group.map_name, [{item_id, 1, x, y, true}], x, y)
    end
  end

  defp maybe_drop_expired_trap(_group, _trap, _unit_available?), do: :ok

  defp spring_trap_now(map_name, x, y, now) do
    groups = map_name |> Storage.get_groups_at_cell(x, y) |> Enum.sort_by(& &1.group_id)

    case select_trap(groups, &spring_eligibility/1) do
      {:ok, %Group{} = group} ->
        expires_at = now + @sprung_trap_lifetime
        sprung = group |> transition_trap(:sprung, expires_at) |> Map.put(:visibility, :public)

        case persist_trap_update(group, sprung) do
          :ok -> {:ok, %{group_id: group.group_id, expires_at: expires_at}}
          {:error, _reason} = error -> error
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp reclaim_trap_now(owner, map_name, x, y) do
    groups = map_name |> Storage.get_groups_at_cell(x, y) |> Enum.sort_by(& &1.group_id)

    case select_trap(groups, &reclaim_eligibility(&1, owner)) do
      {:ok, %Group{state: %{trap: %TrapState{reclaim_item_id: item_id}}} = group} ->
        cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
        {:ok, %{group_id: group.group_id, item_id: item_id}}

      {:error, _reason} = error ->
        error
    end
  end

  defp reveal_traps_now(map_name, x, y, range) do
    with {:ok, groups} <- hidden_supported_traps(map_name, x, y, range) do
      groups
      |> Enum.reduce_while({:ok, []}, &reveal_trap_step/2)
      |> case do
        {:ok, transitions} -> {:ok, publish_revealed_traps(transitions)}
        error -> error
      end
    end
  end

  defp publish_revealed_traps(transitions) do
    transitions = Enum.reverse(transitions)
    Enum.each(transitions, fn {_original, visible} -> publish_revealed_trap(visible) end)
    Enum.map(transitions, fn {_original, visible} -> visible.group_id end)
  end

  defp reveal_trap_step(group, {:ok, transitions}) do
    case reveal_trap(group) do
      {:ok, visible} ->
        {:cont, {:ok, [{group, visible} | transitions]}}

      {:error, _reason} = error ->
        rollback_revealed_traps(transitions)
        {:halt, error}
    end
  end

  defp rollback_revealed_traps(transitions) do
    Enum.each(transitions, fn {original, _visible} ->
      if Group.materialized?(original) do
        Storage.update(original)
      else
        rollback_trap_materialization(original)
      end
    end)
  end

  defp hidden_supported_traps(map_name, x, y, range) do
    map_name
    |> groups_in_area(x, y, range)
    |> Enum.reduce_while({:ok, []}, fn group, {:ok, groups} = result ->
      if Group.public?(group),
        do: {:cont, result},
        else: classify_hidden_trap(group, groups)
    end)
    |> case do
      {:ok, groups} -> {:ok, Enum.reverse(groups)}
      error -> error
    end
  end

  defp classify_hidden_trap(group, groups) do
    case trap_state(group) do
      {:ok, %TrapState{phase: :armed}} -> {:cont, {:ok, [group | groups]}}
      {:ok, %TrapState{}} -> {:cont, {:ok, groups}}
      {:error, :unsupported_trap} -> {:cont, {:ok, groups}}
      {:error, :invalid_trap_state} = error -> {:halt, error}
    end
  end

  defp groups_in_area(map_name, x, y, range) do
    groups =
      for cell_x <- (x - range)..(x + range),
          cell_y <- (y - range)..(y + range),
          group <- Storage.get_groups_at_cell(map_name, cell_x, cell_y),
          uniq: true,
          do: group

    Enum.sort_by(groups, & &1.group_id)
  end

  defp reveal_trap(%Group{} = group) do
    visible = %{group | visibility: :public}

    case Storage.get_cells_by_group(group.group_id) do
      [] ->
        :ok = Storage.update(visible)

        case materialize_visible_cells(visible, []) do
          {:ok, _cells} ->
            {:ok, visible}

          {:error, _reason} = error ->
            rollback_trap_materialization(group)
            error
        end

      [_cell | _cells] ->
        :ok = Storage.update(visible)
        {:ok, visible}
    end
  end

  defp publish_revealed_trap(%Group{} = group) do
    packet = %SkillUnitSpawn{group: View.group(group, Storage.get_cells_by_group(group.group_id))}

    tracked = fn player_id ->
      MapSet.member?(Storage.get_observer_groups(player_id), group.group_id)
    end

    group
    |> reconcile_group()
    |> players_in_range()
    |> then(&eligible_recipients(group, &1))
    |> Enum.reject(tracked)
    |> Enum.each(fn player_id ->
      Broadcast.to_player(player_id, packet)
      Storage.add_observer_group(player_id, group.group_id)
    end)

    :ok
  end

  defp rollback_trap_materialization(%Group{} = original) do
    original.group_id
    |> Storage.get_cells_by_group()
    |> Enum.each(&remove_cell/1)

    Storage.update(original)
  end

  defp select_trap([], _eligibility), do: {:error, :not_found}

  defp select_trap(groups, eligibility) do
    results = Enum.map(groups, &{&1, eligibility.(&1)})

    case Enum.find(results, fn {_group, result} -> result == :eligible end) do
      {group, :eligible} ->
        {:ok, group}

      nil ->
        {_group, {:error, reason}} =
          Enum.find(results, fn {_group, result} -> result != {:error, :unsupported_trap} end) ||
            hd(results)

        {:error, reason}
    end
  end

  defp spring_eligibility(%Group{} = group) do
    case trap_state(group) do
      {:ok, %TrapState{phase: :armed}} -> :eligible
      {:ok, %TrapState{}} -> {:error, :already_spent}
      {:error, _reason} = error -> error
    end
  end

  defp reclaim_eligibility(%Group{} = group, owner) do
    case trap_state(group) do
      {:ok, %TrapState{phase: :armed}} -> reclaim_armed_trap(group, owner)
      {:ok, %TrapState{}} -> {:error, :already_spent}
      {:error, _reason} = error -> error
    end
  end

  defp reclaim_armed_trap(
         %Group{state: %{trap: %TrapState{reclaim_item_id: @trap_item_id}}} = group,
         owner
       ) do
    if {group.caster_type, group.caster_id} == owner,
      do: :eligible,
      else: {:error, :not_owner}
  end

  defp reclaim_armed_trap(_group, _owner), do: {:error, :unsupported_trap}

  defp trap_state(%Group{state: %{trap: %TrapState{} = trap}}) do
    case TrapState.new(Map.from_struct(trap)) do
      {:ok, valid} -> {:ok, valid}
      {:error, :invalid_trap_state} = error -> error
    end
  end

  defp trap_state(%Group{state: state}) do
    if Map.has_key?(state, :trap),
      do: {:error, :invalid_trap_state},
      else: {:error, :unsupported_trap}
  end

  defp register_invisible_group(%Group{} = group) do
    :ok = remove_replaced_group(group.group_id)
    :ok = Storage.insert(group)
    {:ok, group}
  end

  defp register_water_ball_sequence_now(%Group{visibility: :none} = group, cells) do
    with {:ok, _group} <- register_invisible_group(group),
         {:ok, cell_count} <- materialize_water_ball_cells(group, cells),
         true <- cell_count > 0 do
      {:ok, group}
    else
      false ->
        :ok = Storage.delete(group.group_id)
        {:error, :no_water_source}

      {:error, _reason} = error ->
        rollback_visible_cells(group.group_id)
        error
    end
  end

  defp register_water_ball_sequence_now(_group, _cells), do: {:error, :visible_sequence}

  defp materialize_water_ball_cells(group, cells) do
    cells
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, 0}, fn {{x, y}, sequence_index}, {:ok, cell_count} ->
      case materialize_water_ball_cell(group, x, y, sequence_index) do
        {:ok, _cell} -> {:cont, {:ok, cell_count + 1}}
        :skip -> {:cont, {:ok, cell_count}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp materialize_water_ball_cell(group, x, y, sequence_index) do
    with :ok <- consume_water_source(MapCell.water_source(group.map_name, x, y)) do
      create_water_ball_cell(group, x, y, sequence_index)
    end
  end

  defp consume_water_source(%MapCell.WaterSource{origin: :base}), do: :ok

  defp consume_water_source(%MapCell.WaterSource{origin: :skill_unit, cell_id: source_id}) do
    with %Cell{} = source <- Storage.get_cell(source_id),
         %Group{} = owner <- Storage.get(source.group_id) do
      remove_group_cells(owner, MapSet.new([{source.x, source.y}]))
      :ok
    else
      nil -> :skip
    end
  end

  defp consume_water_source(%MapCell.WaterSource{origin: :water_ball}), do: :skip
  defp consume_water_source(nil), do: :skip

  defp create_water_ball_cell(group, x, y, sequence_index) do
    with {:ok, cell_id} <- Id.allocate(),
         {:ok, cell} <-
           Cell.new(%{
             cell_id: cell_id,
             group_id: group.group_id,
             map_name: group.map_name,
             x: x,
             y: y,
             flags: [:consumable_water],
             state: %{water_ball_token: true, water_ball_sequence_index: sequence_index}
           }),
         :ok <- Storage.insert_cell(cell),
         :ok <- commit_terrain(cell) do
      {:ok, cell}
    end
  end

  defp claim_next_sequence_cell(%Group{} = group) do
    case Enum.min_by(
           Storage.get_cells_by_group(group.group_id),
           &water_ball_sequence_index/1,
           fn -> nil end
         ) do
      %Cell{} = cell ->
        :ok = remove_cell(cell)
        {:ok, group}

      nil ->
        :empty
    end
  end

  defp water_ball_sequence_index(%Cell{state: %{water_ball_sequence_index: sequence_index}}),
    do: sequence_index

  defp register_group(%Group{} = group) do
    if Group.materialized?(group),
      do: register_visible_group(group),
      else: register_invisible_group(group)
  end

  defp enforce_instance_limit(%Group{
         lifecycle_policy: %{max_instances_per_caster: nil}
       }),
       do: :ok

  defp enforce_instance_limit(
         %Group{
           group_id: new_group_id,
           lifecycle_policy: %{max_instances_per_caster: max_instances_per_caster}
         } = group
       )
       when is_integer(max_instances_per_caster) and max_instances_per_caster > 0 do
    group.skill_name
    |> Storage.get_groups_by_skill_and_caster(group.caster_type, group.caster_id)
    |> Enum.reject(&(&1.group_id == new_group_id))
    |> Enum.sort_by(&{&1.created_at, &1.group_id})
    |> Enum.drop(-(max_instances_per_caster - 1))
    |> Enum.each(&cleanup_with_reason(&1, :SKILL_UNIT_DESPAWN_REASON_CANCELED))

    :ok
  end

  defp register_visible_group(%Group{} = group) do
    :ok = remove_replaced_group(group.group_id)
    :ok = Storage.insert(group)

    case materialize_visible_cells(group, []) do
      {:ok, _cells} ->
        {:ok, group}

      {:error, _reason} = error ->
        rollback_visible_cells(group.group_id)
        error
    end
  end

  defp schedule_group(%Group{} = group, rng) do
    with {:ok, module} <- handler_for(group),
         true <- function_exported?(module, :schedule, 2) do
      case invoke(module, :schedule, [group, rng]) do
        {:ok, {:ok, %Group{group_id: group_id} = scheduled}} when group_id == group.group_id ->
          {:ok, scheduled}

        {:ok, {:ok, %Group{group_id: group_id}}} ->
          {:error, {:schedule_foreign_group_id, group_id}}

        {:ok, result} ->
          {:error, {:invalid_schedule_return, result}}

        {:error, reason} ->
          {:error, {:schedule_failed, reason}}
      end
    else
      :error -> {:ok, group}
      false -> {:ok, group}
    end
  end

  defp materialize_visible_cells(%Group{cells: cells} = group, stored) do
    Enum.reduce_while(cells, {:ok, stored, Id.first()}, fn {x, y}, {:ok, stored, start} ->
      with {:ok, cell_id} <- Id.allocate(start: start),
           :ok <- ensure_cell_available(group, x, y),
           {:ok, cell} <-
             Cell.new(
               %{
                 cell_id: cell_id,
                 group_id: group.group_id,
                 map_name: group.map_name,
                 x: x,
                 y: y
               }
               |> Map.merge(cell_attrs(group, {x, y}))
               |> Map.put(:flags, [
                 :visible | List.wrap(Map.get(cell_attrs(group, {x, y}), :flags))
               ])
             ),
           :ok <- Storage.insert_cell(cell),
           :ok <- commit_terrain(cell),
           :ok <- register_target(cell) do
        {:cont, {:ok, [cell | stored], cell_id + 1}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, stored, _start} -> {:ok, Enum.reverse(stored)}
      error -> error
    end
  end

  defp rollback_visible_cells(group_id) do
    group_id |> Storage.get_cells_by_group() |> Enum.each(&remove_cell_indexes/1)
    :ok = Storage.delete(group_id)
  end

  defp update_after_interval(%Group{} = updated, now, module) do
    updated = %{updated | next_tick_at: now + updated.interval}
    decay_cells(updated)

    case Storage.get(updated.group_id) do
      nil ->
        :ok

      %Group{} = live ->
        if Group.materialized?(updated) and Storage.get_cells_by_group(live.group_id) == [] do
          cleanup(live, module, :SKILL_UNIT_DESPAWN_REASON_DESTROYED)
        else
          Storage.update(updated)
        end
    end
  end

  defp decay_cells(%Group{state: %{cell_decay: amount}} = group)
       when is_integer(amount) and amount > 0 do
    group.group_id
    |> Storage.get_cells_by_group()
    |> Enum.each(&damage_cell_now(&1.cell_id, amount, nil, :decay))
  end

  defp decay_cells(_group), do: :ok

  defp cell_attrs(%Group{state: %{cell_attrs: attrs}}, cell) when is_map(attrs) do
    Map.get(attrs, cell, %{})
  end

  defp cell_attrs(_group, _cell), do: %{}

  defp ensure_cell_available(%Group{} = group, x, y) do
    if exclusive_terrain?(group) and MapCell.exclusive_contribution?(group.map_name, x, y) do
      {:error, :exclusive_terrain_overlap}
    else
      :ok
    end
  end

  defp exclusive_terrain?(%Group{state: %{exclusive_terrain: true}}), do: true
  defp exclusive_terrain?(_group), do: false

  defp remove_replaced_group(group_id) do
    case Storage.get(group_id) do
      nil ->
        :ok

      group ->
        :ok = FieldSupport.release_group(group_id)
        cells = Storage.get_cells_by_group(group_id)
        Enum.each(cells, &remove_cell_indexes/1)
        :ok = Storage.delete(group_id)

        publish_group_despawn(
          group,
          Enum.map(cells, & &1.cell_id),
          :SKILL_UNIT_DESPAWN_REASON_CANCELED
        )
    end
  end

  defp callback_failed(group, callback, reason, module) do
    log_callback_error(group, callback, reason)
    cleanup(group, module)
  end

  defp log_callback_error(group, callback, reason) do
    Logger.error(
      "Skill.Unit.Manager callback=#{callback} failed skill=#{group.skill_name} " <>
        "group_id=#{group.group_id}: #{inspect(reason)}"
    )
  end

  defp invoke(module, callback, args) do
    {:ok, apply(module, callback, args)}
  rescue
    error -> {:error, {error, __STACKTRACE__}}
  catch
    kind, reason -> {:error, {kind, reason, __STACKTRACE__}}
  end

  defp default_server, do: ProcessTree.get({__MODULE__, :server}) || __MODULE__

  defp reconcile_terrain do
    cells =
      Storage.all()
      |> Enum.flat_map(&Storage.get_cells_by_group(&1.group_id))
      |> Enum.filter(&terrain_cell?/1)

    Enum.each(cells, &commit_terrain/1)

    Storage.all()
    |> Enum.flat_map(&Storage.get_cells_by_group(&1.group_id))
    |> Enum.each(&register_target/1)

    :ok = MapCell.prune_source_kind(:skill_unit, Enum.map(cells, & &1.cell_id))

    :ok
  end

  defp commit_terrain(%Cell{} = cell) do
    traits = terrain_traits(cell)

    case traits do
      [] -> :ok
      _ -> MapCell.put(cell.map_name, cell.x, cell.y, terrain_source(cell), cell.cell_id, traits)
    end
  end

  defp register_target(%Cell{} = cell) do
    if Cell.flag?(cell, :targetable) and cell.hp > 0 do
      :ok = UnitRegistry.register_skill_unit(cell, self())
      SpatialIndex.add_skill_unit(cell)
    else
      :ok
    end
  end

  defp remove_target(%Cell{} = cell) do
    if Cell.flag?(cell, :targetable) do
      :ok = UnitRegistry.unregister_skill_unit(cell.cell_id)
      SpatialIndex.remove_skill_unit(cell.cell_id)
    else
      :ok
    end
  end

  defp remove_terrain(%Cell{} = cell),
    do: MapCell.delete_source(terrain_source(cell), cell.cell_id)

  defp terrain_source(%Cell{state: %{terrain_source: source}}) when is_atom(source), do: source
  defp terrain_source(_cell), do: :skill_unit

  defp terrain_cell?(cell), do: terrain_traits(cell) != []

  defp terrain_traits(cell) do
    []
    |> maybe_put(:blocks_movement, Cell.flag?(cell, :blocks_movement))
    |> maybe_put(:blocks_projectiles, Cell.flag?(cell, :blocks_projectiles))
    |> maybe_put(:exclusive, exclusive_terrain_cell?(cell))
    |> maybe_put(
      :consumable_water,
      Cell.flag?(cell, :consumable_water),
      consumable_water_source(cell)
    )
  end

  defp consumable_water_source(%Cell{state: %{water_ball_token: true}, cell_id: cell_id}),
    do: {:water_ball, cell_id}

  defp consumable_water_source(%Cell{cell_id: cell_id}), do: cell_id

  defp exclusive_terrain_cell?(%Cell{state: %{exclusive_terrain: true}}), do: true
  defp exclusive_terrain_cell?(_cell), do: false

  defp maybe_put(traits, _key, false), do: traits
  defp maybe_put(traits, key, true), do: Keyword.put(traits, key, true)
  defp maybe_put(traits, key, true, value), do: Keyword.put(traits, key, value)
  defp maybe_put(traits, _key, false, _value), do: traits

  defp reconcile_group(%Group{} = group) do
    case field_support_spec(group) do
      {:ok, spec} ->
        occupants = occupants(group, spec)

        if not field_support_current?(group, spec, occupants) do
          acquire_occupants(group, spec, occupants)
          release_missing(group, spec, occupants)
        end

        group

      :error ->
        group
    end
  end

  defp occupants(%Group{} = group, spec) do
    group.cells
    |> Enum.flat_map(fn {x, y} ->
      SpatialIndex.get_all_units_in_range(group.map_name, x, y, 0)
    end)
    |> Enum.filter(&(living_combat_unit?(&1) and supports_target?(spec, &1)))
    |> MapSet.new()
  end

  defp living_combat_unit?({unit_type, unit_id})
       when unit_type in [:player, :mob, :homunculus] do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _ -> false
    end
  end

  defp living_combat_unit?(_unit), do: false

  defp field_support_current?(group, spec, occupants) do
    expected = MapSet.new(occupants, &{elem(&1, 0), elem(&1, 1), spec.status_type})

    actual =
      group.group_id
      |> FieldSupport.sources_for_group()
      |> MapSet.new(fn {unit_type, unit_id, status_type, _params} ->
        {unit_type, unit_id, status_type}
      end)

    expected == actual
  end

  defp acquire_occupants(group, spec, occupants) do
    Enum.each(occupants, fn {unit_type, unit_id} ->
      if supports_target?(spec, {unit_type, unit_id}) do
        FieldSupport.acquire(
          unit_type,
          unit_id,
          spec.status_type,
          group.group_id,
          params_for(spec, unit_type, unit_id)
        )
      end
    end)
  end

  defp release_missing(group, spec, occupants) do
    occupied = MapSet.new(occupants)

    group.group_id
    |> FieldSupport.sources_for_group()
    |> Enum.each(fn {unit_type, unit_id, status_type, _params} ->
      if not MapSet.member?(occupied, {unit_type, unit_id}) or
           not supports_target?(spec, {unit_type, unit_id}) do
        FieldSupport.release(unit_type, unit_id, status_type, group.group_id)
      end
    end)
  end

  defp reconcile_unit_support({unit_type, unit_id}) do
    current_groups =
      case SpatialIndex.get_unit_position(unit_type, unit_id) do
        {:ok, {x, y, map_name}} -> Storage.get_groups_at_cell(map_name, x, y)
        _ -> []
      end

    current_ids =
      current_groups
      |> Enum.filter(fn group ->
        case field_support_spec(group) do
          {:ok, spec} ->
            living_combat_unit?({unit_type, unit_id}) and
              supports_target?(spec, {unit_type, unit_id})

          :error ->
            false
        end
      end)
      |> MapSet.new(& &1.group_id)

    Enum.each(current_groups, fn group ->
      apply_field_support_action(group, {unit_type, unit_id}, :on_touch)
    end)

    FieldSupport.sources_for_unit(unit_type, unit_id)
    |> Enum.each(fn {_, _, status_type, group_id, _params} ->
      if not MapSet.member?(current_ids, group_id) do
        FieldSupport.release(unit_type, unit_id, status_type, group_id)
      end
    end)
  end

  defp field_support_spec(%Group{} = group) do
    with {:ok, module} <- handler_for(group),
         true <- function_exported?(module, :field_support, 1) do
      {:ok, %{status_type: _, params: _, target?: _} = module.field_support(group)}
    else
      _ -> :error
    end
  end

  defp params_for(%{params: params}, unit_type, unit_id) when is_function(params, 2),
    do: params.(unit_type, unit_id)

  defp params_for(%{params: params}, _unit_type, _unit_id), do: params

  defp supports_target?(%{target?: target?}, target), do: target?.(target)

  defp handler_for(%Group{handler: handler}) when not is_nil(handler), do: {:ok, handler}
  defp handler_for(%Group{skill_name: skill_name}), do: Catalog.ground_module_for(skill_name)
end
