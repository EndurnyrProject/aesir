defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Manager do
  @moduledoc """
  Serializes every ground skill-unit mutation and drives interval/expiry ticks.

  Storage reads remain direct, while registration, callback updates, explicit
  state changes, and teardown pass through this process so the primary row and
  every secondary index change as one ordered operation.
  """

  use GenServer

  require Logger

  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundNuke
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @tick_interval 100

  @type server :: GenServer.server()
  @type mover :: {atom(), integer()}

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
  @spec register(Group.t()) :: :ok
  def register(%Group{} = group), do: register(default_server(), group)

  @doc false
  @spec register(server(), Group.t()) :: :ok
  def register(server, %Group{} = group), do: GenServer.call(server, {:register, group})

  @doc "Merges skill-owned state into a live group without resurrecting a deleted one."
  @spec update_state(non_neg_integer(), map()) :: :ok
  def update_state(group_id, state), do: update_state(default_server(), group_id, state)

  @doc false
  @spec update_state(server(), non_neg_integer(), map()) :: :ok
  def update_state(server, group_id, state) do
    GenServer.call(server, {:update_state, group_id, state})
  end

  @doc "Runs cleanup and destroys a live group."
  @spec destroy(non_neg_integer()) :: :ok
  def destroy(group_id), do: destroy(default_server(), group_id)

  @doc false
  @spec destroy(server(), non_neg_integer()) :: :ok
  def destroy(server, group_id), do: GenServer.call(server, {:destroy, group_id})

  @doc "Creates an independently indexed cell owned by an existing group."
  @spec create_cell(non_neg_integer(), map()) :: {:ok, Cell.t()} | {:error, term()}
  def create_cell(group_id, attrs), do: create_cell(default_server(), group_id, attrs)

  @doc false
  @spec create_cell(server(), non_neg_integer(), map()) :: {:ok, Cell.t()} | {:error, term()}
  def create_cell(server, group_id, attrs),
    do: GenServer.call(server, {:create_cell, group_id, attrs})

  @doc "Updates one live cell."
  @spec update_cell(non_neg_integer(), map()) :: {:ok, Cell.t()} | {:error, :not_found | term()}
  def update_cell(cell_id, attrs), do: update_cell(default_server(), cell_id, attrs)

  @doc false
  @spec update_cell(server(), non_neg_integer(), map()) ::
          {:ok, Cell.t()} | {:error, :not_found | term()}
  def update_cell(server, cell_id, attrs),
    do: GenServer.call(server, {:update_cell, cell_id, attrs})

  @doc "Applies damage once against the current cell HP."
  @spec damage_cell(non_neg_integer(), pos_integer()) ::
          {:ok, Cell.t()} | {:destroyed, Cell.t()} | {:error, term()}
  def damage_cell(cell_id, amount), do: damage_cell(default_server(), cell_id, amount)

  @doc false
  @spec damage_cell(server(), non_neg_integer(), pos_integer()) ::
          {:ok, Cell.t()} | {:destroyed, Cell.t()} | {:error, term()}
  def damage_cell(server, cell_id, amount),
    do: GenServer.call(server, {:damage_cell, cell_id, amount})

  @doc "Applies natural decay through the same serialized damage operation."
  @spec decay_cell(non_neg_integer(), pos_integer()) ::
          {:ok, Cell.t()} | {:destroyed, Cell.t()} | {:error, term()}
  def decay_cell(cell_id, amount), do: damage_cell(cell_id, amount)

  @doc false
  @spec decay_cell(server(), non_neg_integer(), pos_integer()) ::
          {:ok, Cell.t()} | {:destroyed, Cell.t()} | {:error, term()}
  def decay_cell(server, cell_id, amount), do: damage_cell(server, cell_id, amount)

  @doc "Claims a consumable source cell exactly once."
  @spec claim_cell(non_neg_integer()) :: {:ok, Cell.t()} | {:error, :not_claimable | :not_found}
  def claim_cell(cell_id), do: claim_cell(default_server(), cell_id)

  @doc false
  @spec claim_cell(server(), non_neg_integer()) ::
          {:ok, Cell.t()} | {:error, :not_claimable | :not_found}
  def claim_cell(server, cell_id), do: GenServer.call(server, {:claim_cell, cell_id})

  @doc "Removes one cell idempotently."
  @spec destroy_cell(non_neg_integer()) :: :ok
  def destroy_cell(cell_id), do: destroy_cell(default_server(), cell_id)

  @doc false
  @spec destroy_cell(server(), non_neg_integer()) :: :ok
  def destroy_cell(server, cell_id), do: GenServer.call(server, {:destroy_cell, cell_id})

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
  def tick(server, now), do: GenServer.call(server, {:tick, now})

  @impl true
  def init(opts) do
    :ok = Lifecycle.subscribe()

    state = %{
      clock: Keyword.get(opts, :clock, fn -> System.monotonic_time(:millisecond) end),
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
    result = Storage.insert(group)
    reconcile_group(group)
    {:reply, result, state}
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

  def handle_call({:destroy, group_id}, _from, state) do
    if group = Storage.get(group_id), do: cleanup(group)
    {:reply, :ok, state}
  end

  def handle_call({:create_cell, group_id, attrs}, _from, state) do
    result =
      with %Group{} = group <- Storage.get(group_id),
           {:ok, cell_id} <- Id.allocate(),
           {:ok, cell} <-
             Cell.new(
               attrs
               |> Map.put(:cell_id, cell_id)
               |> Map.put(:group_id, group_id)
               |> Map.put(:map_name, group.map_name)
             ),
           :ok <- Storage.insert_cell(cell),
           :ok <- Storage.update(%{group | cell_ids: [cell_id | group.cell_ids]}) do
        {:ok, cell}
      else
        nil -> {:error, :group_not_found}
        {:error, _reason} = error -> error
      end

    {:reply, result, state}
  end

  def handle_call({:update_cell, cell_id, attrs}, _from, state) do
    result =
      case Storage.get_cell(cell_id) do
        nil ->
          {:error, :not_found}

        cell ->
          update_cell_now(cell, attrs)
      end

    {:reply, result, state}
  end

  def handle_call({:damage_cell, cell_id, amount}, _from, state) do
    result = damage_cell_now(cell_id, amount)
    {:reply, result, state}
  end

  def handle_call({:claim_cell, cell_id}, _from, state) do
    result =
      case Storage.get_cell(cell_id) do
        %Cell{} = cell ->
          if Cell.flag?(cell, :consumable_water) do
            :ok = remove_cell(cell)
            {:ok, cell}
          else
            {:error, :not_claimable}
          end

        nil ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  def handle_call({:destroy_cell, cell_id}, _from, state) do
    if cell = Storage.get_cell(cell_id), do: remove_cell(cell)
    {:reply, :ok, state}
  end

  def handle_call({:trigger, group_id, mover, callback}, _from, state) do
    if group = Storage.get(group_id), do: run_trigger(group, mover, callback)
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
      :expire -> cleanup(group)
      :persist_inert -> persist_inert(group)
      _action -> :ok
    end
  end

  defp policy_field(:caster), do: :on_caster_loss
  defp policy_field(:target), do: :on_target_loss

  defp process_tick(now, unit_available?) do
    due = Storage.get_due_groups(now)
    expired = Storage.get_expired_groups(now)

    Enum.each(due, &run_interval(&1, now, unit_available?))
    Enum.each(expired, &expire_if_live/1)
  end

  defp run_interval(%Group{} = group, now, unit_available?) do
    reconcile_group(group)

    case lifecycle_action(group, unit_available?) do
      :continue -> run_interval_callback(group, now)
      :expire -> cleanup(group)
      :skip_action -> Storage.update(%{group | next_tick_at: now + group.interval})
      :persist_inert -> persist_inert(group)
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
      group.lifecycle_policy
      |> Map.fetch!(policy_field(relation))
      |> normalize_loss_action()
    end
  end

  defp unit_identity(group, :caster), do: {group.caster_type, group.caster_id}
  defp unit_identity(group, :target), do: {group.target_type, group.target_id}

  defp normalize_loss_action({:continue_with_combat_snapshot, _snapshot}), do: :continue
  defp normalize_loss_action(action), do: action

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

  defp unit_available?(_unit_type, _unit_id, _map_name), do: false

  defp persist_inert(%Group{} = group) do
    Storage.update(%{
      group
      | next_tick_at: nil,
        state: Map.put(group.state, :lifecycle_inert, true)
    })
  end

  defp invoke_interval(module, group, now) do
    case invoke(module, :on_interval, [group, now]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        Storage.update(%{updated | next_tick_at: now + updated.interval})

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

  defp expire_if_live(%Group{group_id: group_id}) do
    if group = Storage.get(group_id), do: cleanup(group)
  end

  defp run_trigger(%Group{} = group, mover, callback) do
    case handler_for(group) do
      {:ok, module} ->
        run_callback_trigger(group, mover, callback, module)

      _ ->
        apply_field_support_action(group, mover, callback)
    end
  end

  defp run_callback_trigger(group, mover, callback, module) do
    if function_exported?(module, callback, 2) do
      invoke_trigger(group, mover, callback, module)
    else
      apply_field_support_action(group, mover, callback)
    end
  end

  defp invoke_trigger(group, mover, callback, module) do
    case invoke(module, callback, [group, mover]) do
      {:ok, {:ok, %Group{group_id: group_id} = updated}} when group_id == group.group_id ->
        Storage.update(updated)
        apply_field_support_action(updated, mover, callback)

      {:ok, {:ok, %Group{group_id: group_id}}} ->
        callback_failed(group, callback, {:foreign_group_id, group_id}, module)

      {:ok, :expire} ->
        cleanup(group, module)

      {:ok, result} ->
        callback_failed(group, callback, {:invalid_return, result}, module)

      {:error, reason} ->
        callback_failed(group, callback, reason, module)
    end
  end

  defp apply_field_support_action(%Group{} = group, {unit_type, unit_id}, :on_touch) do
    with {:ok, spec} <- field_support_spec(group) do
      if supports_target?(spec, {unit_type, unit_id}) do
        FieldSupport.acquire(
          unit_type,
          unit_id,
          spec.status_type,
          group.group_id,
          params_for(spec, unit_type, unit_id),
          aggregate: spec.aggregate
        )
        |> log_field_support_failure(group, :acquire)
      else
        FieldSupport.release(unit_type, unit_id, spec.status_type, group.group_id,
          aggregate: spec.aggregate
        )
        |> log_field_support_failure(group, :release)
      end
    end

    :ok
  end

  defp apply_field_support_action(%Group{} = group, {unit_type, unit_id}, :on_out) do
    with {:ok, spec} <- field_support_spec(group) do
      FieldSupport.release(
        unit_type,
        unit_id,
        spec.status_type,
        group.group_id,
        aggregate: spec.aggregate
      )
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

  defp cleanup(%Group{} = group) do
    module =
      case handler_for(group) do
        {:ok, handler} -> handler
        :error -> nil
      end

    cleanup(group, module)
  end

  defp cleanup(%Group{group_id: group_id} = group, module) do
    FieldSupport.release_group(group_id)

    if module && function_exported?(module, :on_expire, 1) do
      case invoke(module, :on_expire, [group]) do
        {:ok, :ok} -> :ok
        {:ok, result} -> log_callback_error(group, :on_expire, {:invalid_return, result})
        {:error, reason} -> log_callback_error(group, :on_expire, reason)
      end
    end

    Storage.delete(group_id)
  end

  defp damage_cell_now(_cell_id, amount) when not is_integer(amount) or amount <= 0,
    do: {:error, :invalid_damage}

  defp damage_cell_now(cell_id, amount) do
    case Storage.get_cell(cell_id) do
      nil ->
        {:error, :not_found}

      %Cell{max_hp: 0} ->
        {:error, :not_destructible}

      %Cell{hp: hp} = cell when amount < hp ->
        updated = %{cell | hp: hp - amount}
        :ok = Storage.update_cell(updated)
        {:ok, updated}

      %Cell{} = cell ->
        :ok = remove_cell(cell)
        {:destroyed, cell}
    end
  end

  defp update_cell_now(_cell, attrs)
       when is_map_key(attrs, :cell_id) or is_map_key(attrs, :group_id) or
              is_map_key(attrs, :map_name) or is_map_key(attrs, :x) or is_map_key(attrs, :y),
       do: {:error, :immutable_cell_field}

  defp update_cell_now(cell, attrs) do
    case Cell.new(Map.merge(Map.from_struct(cell), attrs)) do
      {:ok, updated} ->
        :ok = Storage.update_cell(updated)
        {:ok, updated}

      error ->
        error
    end
  end

  defp remove_cell(%Cell{} = cell) do
    :ok = Storage.delete_cell(cell.cell_id)

    case Storage.get(cell.group_id) do
      nil ->
        :ok

      %Group{} = group ->
        remaining = List.delete(group.cell_ids, cell.cell_id)
        :ok = Storage.update(%{group | cell_ids: remaining})
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

  defp reconcile_group(%Group{} = group) do
    with {:ok, spec} <- field_support_spec(group) do
      occupants = occupants(group)
      acquire_occupants(group, spec, occupants)
      release_missing(group, spec, occupants)
    end

    :ok
  end

  defp occupants(%Group{} = group) do
    group.cells
    |> Enum.flat_map(fn {x, y} ->
      SpatialIndex.get_all_units_in_range(group.map_name, x, y, 0)
    end)
    |> Enum.uniq()
  end

  defp acquire_occupants(group, spec, occupants) do
    Enum.each(occupants, fn {unit_type, unit_id} ->
      if supports_target?(spec, {unit_type, unit_id}) do
        FieldSupport.acquire(
          unit_type,
          unit_id,
          spec.status_type,
          group.group_id,
          params_for(spec, unit_type, unit_id),
          aggregate: spec.aggregate
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
        FieldSupport.release(unit_type, unit_id, status_type, group.group_id,
          aggregate: spec.aggregate
        )
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
          {:ok, spec} -> supports_target?(spec, {unit_type, unit_id})
          :error -> false
        end
      end)
      |> MapSet.new(& &1.group_id)

    Enum.each(current_groups, &apply_field_support_action(&1, {unit_type, unit_id}, :on_touch))

    FieldSupport.sources_for_unit(unit_type, unit_id)
    |> Enum.each(fn {_, _, status_type, group_id, _params} ->
      if not MapSet.member?(current_ids, group_id) do
        FieldSupport.release(unit_type, unit_id, status_type, group_id)
      end
    end)
  end

  defp field_support_spec(%Group{} = group) do
    with {:ok, module} <- handler_for(group),
         true <- function_exported?(module, :field_support, 1),
         {:ok, spec} <- normalize_field_support(module.field_support(group)) do
      {:ok, spec}
    else
      _ -> normalize_field_support(Map.get(group.state, :field_support))
    end
  end

  defp normalize_field_support({:ok, spec}), do: normalize_field_support(spec)
  defp normalize_field_support(nil), do: :error

  defp normalize_field_support(%{status_type: status_type, params: params} = spec) do
    {:ok,
     %{
       status_type: status_type,
       params: params,
       aggregate: Map.get(spec, :aggregate),
       target?: Map.get(spec, :target?)
     }}
  end

  defp normalize_field_support(%{status: status_type, params: params} = spec) do
    normalize_field_support(%{
      status_type: status_type,
      params: params,
      aggregate: Map.get(spec, :aggregate),
      target?: Map.get(spec, :target?)
    })
  end

  defp normalize_field_support({status_type, params}),
    do: normalize_field_support(%{status_type: status_type, params: params})

  defp normalize_field_support(_spec), do: :error

  defp params_for(%{params: params}, unit_type, unit_id) when is_function(params, 2),
    do: params.(unit_type, unit_id)

  defp params_for(%{params: params}, _unit_type, _unit_id), do: params

  defp supports_target?(%{target?: target?}, target) when is_function(target?, 1),
    do: target?.(target)

  defp supports_target?(_spec, _target), do: true

  defp handler_for(%Group{caster_type: :mob}), do: {:ok, GroundNuke}
  defp handler_for(%Group{skill_name: skill_name}), do: Catalog.ground_module_for(skill_name)
end
