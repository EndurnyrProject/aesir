defmodule Aesir.ZoneServer.Mmo.StatusEffect.Applier do
  @moduledoc """
  Starts a status on a unit.

  `apply_status/4` runs the start gates of
  `Aesir.ZoneServer.Mmo.StatusEffect.StartChecks`, ends what the definition
  ends on start, meets the held instance through `overlap/3`, runs `on_apply`
  and stores the instance through the storage's compare-and-swap, then
  reconciles the statuses the stored instance replaced. A loaded application
  (a persistence restore) skips the gates and stores as-is.
  """
  require Logger

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.MobParameters
  alias Aesir.ZoneServer.Mmo.StatusEffect.Notifications
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Removal
  alias Aesir.ZoneServer.Mmo.StatusEffect.StartChecks
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type unit_type :: Unit.unit_type()
  @type status_event :: Notifications.status_event()

  @doc """
  Applies a status effect to a unit.

  Returns `:ok` on success (including when the effect's `on_apply` consumed
  the application), or `{:error, reason}` when the status is unknown or the
  target is immune, protected or resisted it. Monster admission also rejects
  scripted player bonuses and unsupported mount/custom numeric statuses,
  including loaded applications; restoration never expands target eligibility.

  A status-immune target (a monster of the boss, guardian or battlefield class)
  rejects a status whose definition carries the `:boss` immunity (status.yml
  `BossResist`), whoever its source, with `{:error, :immune}`; every other
  status reaches it like any unit.

  Passing `loaded: true` marks the application as the restore of a persisted
  status: it already passed every gate when first applied, so immunity,
  prevention, conflict and resistance checks are skipped and the given
  `duration` is used as-is. A loaded finite definition requires a positive
  integer duration. A ticking status takes its first tick `first_tick`
  milliseconds after it starts when given (a restore passes the time that was
  left until its next tick when saved), then every interval.

  `owner_refresh: :notify` publishes status identity/event notifications for
  committed mutations, including removals from a cure-only or failed start.
  Applications default to `:auto`: the owning session's handlers reconcile
  synchronously, so an application made from that session defers, while one
  made from another process notifies the owner. Retained overlaps notify nothing.

  A skill may pass `success_rate` (a percentage) and `resistance_roll` (given
  the final per-10000 rate) to combine its base application chance with the
  status defense (`Resistance.defend/2`) in one injectable final roll. The
  source of the defense is the caster (`caster_id`, typed by `source_type` or
  the unit registry), or the target itself without a caster; a caster no
  longer in the world leaves the status undefended and unrolled.
  `no_rate_def: true` rolls the given chance without the target's rate
  defense; `no_tick_def: true` keeps the given duration.
  `bypass_resistance: true` skips the roll and all chance/stat/duration
  resistance while retaining immunity, prevention, and conflict gates.
  `duration: :infinite` starts the status with no expiry (an equipment
  script's endless status); a status with a defense recipe cannot start that
  way and returns `{:error, :infinite_defended_status}`.
  `no_avoid: true` additionally skips the immunity gates (race, element, boss and
  magic immunity). A definition's `:failed_mado` flag still refuses that start
  while the target carries the Madogear option.

  `start_delay: ms` starts the status that many milliseconds later: the
  immunity, Fail-list and defense checks run now and the application returns
  `:ok`; the rest (body-state replacement, end-on-start, overlap, storing) runs
  at the end of the delay if the target is still in the world and alive.
  Renewal shortens the duration by the delay. Bleeding ignores it and
  Stonewait's own wait is its delay.

  When a status listed in the definition's `end_return` is active, the
  application ends every such status instead and returns `:ok` without storing.
  """
  @spec apply_status(unit_type(), integer(), atom(), StatusEntry.status_params()) ::
          :ok | {:error, atom()}
  def apply_status(unit_type, unit_id, status_id, status_params \\ []) do
    unit_type
    |> apply_status_with_events(unit_id, status_id, status_params)
    |> without_events()
  end

  @doc "Applies a status and returns its committed lifecycle mutations, including partial failures."
  @spec apply_status_with_events(unit_type(), integer(), atom(), StatusEntry.status_params()) ::
          {:ok, [status_event()]} | {:error, term(), [status_event()]}
  def apply_status_with_events(unit_type, unit_id, status_id, status_params) do
    result =
      case Registry.get_definition(status_id) do
        nil ->
          Logger.warning("Unknown status effect: #{status_id}")
          {:error, :unknown_status}

        definition ->
          apply_known_status(unit_type, unit_id, status_id, status_params, definition)
      end

    finish_apply_result(result, unit_type, unit_id, status_params)
  end

  defp finish_apply_result(result, unit_type, unit_id, status_params) do
    outcome = event_result(result)

    events =
      case outcome do
        {:ok, committed} -> committed
        {:error, _reason, committed} -> committed
      end

    Notifications.maybe_refresh_owner(unit_type, unit_id, events, status_params)
    outcome
  end

  defp event_result(:ok), do: {:ok, []}
  defp event_result({:error, reason}), do: {:error, reason, []}
  defp event_result(result), do: result

  defp without_events({:ok, _events}), do: :ok
  defp without_events({:error, reason, _events}), do: {:error, reason}

  defp apply_known_status(unit_type, unit_id, status_id, status_params, definition) do
    with :ok <- StartChecks.ensure_eligible_target(unit_type, definition),
         :ok <- StartChecks.ensure_living_target(unit_type, unit_id),
         :ok <- StartChecks.ensure_status_allowed(unit_type, unit_id, status_id),
         :ok <- StartChecks.check_failed_mado(unit_type, unit_id, definition, status_params) do
      if Keyword.get(status_params, :loaded, false) do
        apply_loaded_status(unit_type, unit_id, status_id, status_params, definition)
      else
        apply_new_status(unit_type, unit_id, status_id, status_params, definition)
      end
    end
  end

  # Reference order: boss immunity (BossResist), then EndReturn, then the Fail
  # list, then the status defense (magic immunity first).
  defp apply_new_status(unit_type, unit_id, status_id, status_params, definition) do
    entity_info = StartChecks.entity_info(unit_type, unit_id)

    with :ok <- StartChecks.check_resisted(entity_info, status_params, definition) do
      case Enum.filter(definition.end_return, &StatusStorage.has_status?(unit_type, unit_id, &1)) do
        [] ->
          apply_unreturned_status(
            unit_type,
            unit_id,
            status_id,
            status_params,
            definition,
            entity_info
          )

        active ->
          Removal.remove_statuses_with_events(unit_type, unit_id, active, status_params)
      end
    end
  end

  defp apply_unreturned_status(
         unit_type,
         unit_id,
         status_id,
         status_params,
         definition,
         entity_info
       ) do
    duration_override = Keyword.get(status_params, :duration)

    with :ok <- StartChecks.check_avoidable(entity_info, status_params, definition),
         :ok <- StartChecks.check_prevented(unit_type, unit_id, definition),
         :ok <- StartChecks.check_conflicts(unit_type, unit_id, definition),
         :ok <- StartChecks.check_defended_magic(unit_type, unit_id, status_params),
         {:ok, duration} <-
           StartChecks.roll_resistance(
             unit_type,
             unit_id,
             status_id,
             definition,
             entity_info,
             duration_override,
             status_params
           ) do
      start(unit_type, unit_id, status_id, status_params, definition, duration)
    end
  end

  # A `start_delay` defers everything after the status defense by that many
  # milliseconds: the application reports success now, and the status starts
  # at the end of the delay if its target still lives. Renewal shortens the
  # duration by the delay. Bleeding always starts at once, and Stonewait's wait
  # is already its own delay.
  defp start(unit_type, unit_id, status_id, status_params, definition, duration) do
    case start_delay(status_id, status_params) do
      0 ->
        create_and_store(unit_type, unit_id, status_id, status_params, definition, duration)

      delay ->
        duration = delayed_duration(duration, delay)
        # The caller refreshed before the status existed: the start notifies.
        status_params = Keyword.put(status_params, :owner_refresh, :notify)

        {:ok, _task} =
          Task.start(fn ->
            Process.sleep(delay)
            start_delayed(unit_type, unit_id, status_id, status_params, duration)
          end)

        :ok
    end
  end

  defp start_delay(status_id, _params) when status_id in [:sc_bleeding, :sc_stonewait], do: 0

  defp start_delay(_status_id, params) do
    case Keyword.get(params, :start_delay, 0) do
      delay when is_integer(delay) and delay > 0 -> delay
      _none -> 0
    end
  end

  defp delayed_duration(nil, _delay), do: nil

  defp delayed_duration(duration, delay) do
    if GameMode.mode() == :renewal, do: max(1, duration - delay), else: duration
  end

  # The target must still be in the world and alive when the delay ends.
  defp start_delayed(unit_type, unit_id, status_id, status_params, duration) do
    with %{} = definition <- Registry.get_definition(status_id),
         {:ok, {_module, target_state, _pid}} <- UnitRegistry.get_unit(unit_type, unit_id),
         true <- Unit.living?(target_state) do
      unit_type
      |> create_and_store(unit_id, status_id, status_params, definition, duration)
      |> finish_apply_result(unit_type, unit_id, status_params)
    end
  end

  defp apply_loaded_status(unit_type, unit_id, status_id, status_params, definition) do
    with {:ok, duration} <- loaded_duration(definition, status_params) do
      create_and_store(unit_type, unit_id, status_id, status_params, definition, duration)
    end
  end

  defp loaded_duration(%{permanent: true}, _status_params), do: {:ok, nil}

  defp loaded_duration(_definition, status_params) do
    case Keyword.get(status_params, :duration) do
      nil -> {:ok, nil}
      duration when is_integer(duration) and duration > 0 -> {:ok, duration}
      _invalid -> {:error, :invalid_duration}
    end
  end

  defp create_and_store(unit_type, unit_id, status_id, status_params, definition, duration) do
    {val1, val2, val3, val4, tick, flag, caster_id, _duration, state, phase} =
      StatusEntry.extract_params(status_params)

    tick = resolve_tick(tick, definition)
    now_ms = System.monotonic_time(:millisecond)
    source_type = StatusEntry.resolve_source_type(unit_type, unit_id, caster_id, status_params)

    instance = %StatusEntry{
      type: status_id,
      val1: val1,
      val2: val2,
      val3: val3,
      val4: val4,
      tick: tick,
      flag: flag,
      source_id: caster_id,
      source_type: source_type,
      state: state,
      phase: phase || definition.initial_phase,
      started_at: now_ms,
      next_tick_at: StatusEntry.first_tick_at(tick, status_params, now_ms),
      tick_count: 0,
      expires_at: nil
    }

    instance =
      if unit_type == :mob and not Keyword.get(status_params, :loaded, false),
        do:
          MobParameters.initialize(
            instance,
            GameMode.mode(),
            monster_parameter_context(unit_id, instance)
          ),
        else: instance

    context = %{loaded: Keyword.get(status_params, :loaded, false)}

    case definition.module.before_overlap({unit_type, unit_id}, instance, context) do
      :continue ->
        meet_overlap(unit_type, unit_id, status_id, status_params, definition, duration, instance)

      {:end_only, status_ids} ->
        Removal.remove_statuses_with_events(unit_type, unit_id, status_ids, status_params)

      {:continue, actions} ->
        status_ids = Enum.map(actions, fn {:end_status, id} -> id end)

        {:ok, events} =
          Removal.remove_statuses_with_events(unit_type, unit_id, status_ids, status_params)

        unit_type
        |> meet_overlap(unit_id, status_id, status_params, definition, duration, instance)
        |> prepend_events(events)
    end
  end

  defp resolve_tick(tick, _definition) when tick > 0, do: tick
  defp resolve_tick(_tick, %{tick_interval: interval}) when is_integer(interval), do: interval
  defp resolve_tick(tick, _definition), do: tick

  defp monster_parameter_context(unit_id, instance) do
    source_present? =
      is_integer(instance.source_id) and
        UnitRegistry.unit_exists?(instance.source_type, instance.source_id)

    :mob
    |> StartChecks.entity_info(unit_id)
    |> Map.put(:source_present, source_present?)
  end

  defp meet_overlap(unit_type, unit_id, status_id, status_params, definition, duration, instance) do
    definition = %{definition | end_on_start: ended_on_start(unit_type, unit_id, definition)}
    held = held_instance(unit_type, unit_id, status_id, definition)

    case overlap(definition, {unit_type, unit_id}, held, instance) do
      {:replace, adjusted} ->
        start_application(unit_type, unit_id, status_id, status_params, definition, duration, {
          adjusted,
          held,
          instance
        })

      refused ->
        {:ok, events} = end_ended_on_start(unit_type, unit_id, status_id, definition)
        prepend_events(overlap_result(refused), events)
    end
  end

  defp start_application(
         unit_type,
         unit_id,
         status_id,
         status_params,
         definition,
         duration,
         {instance, held, incoming}
       ) do
    {duration, instance} =
      resolve_duration(definition, {unit_type, unit_id}, instance, duration, status_params)

    context =
      unit_type
      |> ContextBuilder.build_context(unit_id, instance.source_id, instance)
      |> Map.merge(%{duration: duration, loaded: Keyword.get(status_params, :loaded, false)})

    case definition.module.on_apply({unit_type, unit_id}, instance, context) do
      {:ok, new_instance} ->
        store_applied_status(
          unit_type,
          unit_id,
          status_id,
          duration,
          definition,
          {instance, held, incoming},
          new_instance,
          status_params
        )

      :remove ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepend_events(result, events) do
    case event_result(result) do
      {:ok, committed} -> {:ok, events ++ committed}
      {:error, reason, committed} -> {:error, reason, events ++ committed}
    end
  end

  defp ended_on_start(unit_type, unit_id, %{opt1: opt1} = definition) when not is_nil(opt1) do
    body_states =
      unit_type
      |> StatusStorage.get_unit_statuses(unit_id)
      |> Enum.filter(&body_state?(&1.type))
      |> Enum.map(& &1.type)

    Enum.uniq(definition.end_on_start ++ body_states)
  end

  defp ended_on_start(_unit_type, _unit_id, definition), do: definition.end_on_start

  defp body_state?(status_id) do
    case Registry.get_definition(status_id) do
      %{opt1: opt1} -> not is_nil(opt1)
      nil -> false
    end
  end

  defp held_instance(unit_type, unit_id, status_id, definition) do
    if status_id in definition.end_on_start,
      do: nil,
      else: StatusStorage.get_status(unit_type, unit_id, status_id)
  end

  defp overlap(_definition, _target, nil, instance), do: {:replace, instance}

  defp overlap(definition, target, held, instance) do
    case definition.module.overlap(target, held, instance) do
      :replace -> {:replace, instance}
      decision -> decision
    end
  end

  defp overlap_result(:keep), do: :ok
  defp overlap_result(:fail), do: {:error, :overlap_refused}

  # A refused application still ends what it ends on start.
  defp end_ended_on_start(unit_type, unit_id, status_id, definition) do
    Removal.remove_statuses_with_events(
      unit_type,
      unit_id,
      List.delete(definition.end_on_start, status_id),
      []
    )
  end

  # Inside the store's compare-and-swap the application meets what is current
  # again when it is no longer `held`: an instance stored, or the held one removed,
  # in between. `incoming` is the application before `overlap/3` adjusted it; an
  # unadjusted replacement keeps the values `on_apply` set (`applied`).
  defp store_decision(definition, target, held, incoming, applied) do
    if incoming.type in definition.end_on_start do
      fn _current -> :store end
    else
      fn
        current when current === held ->
          :store

        current ->
          definition |> overlap(target, current, incoming) |> race_decision(incoming, applied)
      end
    end
  end

  defp race_decision({:replace, incoming}, incoming, applied),
    do: stored_decision({:replace, applied})

  defp race_decision(decision, _incoming, _applied), do: stored_decision(decision)

  defp stored_decision({:replace, adjusted}),
    do:
      {:store,
       &%{
         &1
         | val1: adjusted.val1,
           val2: adjusted.val2,
           val3: adjusted.val3,
           val4: adjusted.val4
       }}

  defp stored_decision(_refused), do: :keep

  defp resolve_duration(_definition, _target, instance, nil, _status_params), do: {nil, instance}

  defp resolve_duration(definition, target, instance, duration, status_params) do
    cond do
      Keyword.get(status_params, :loaded, false) ->
        {duration, instance}

      function_exported?(definition.module, :resolve_duration, 3) ->
        definition.module.resolve_duration(target, instance, duration)

      true ->
        definition.module.resolve_duration(instance, duration)
    end
  end

  defp store_applied_status(
         unit_type,
         unit_id,
         status_id,
         duration,
         definition,
         {instance, held, incoming},
         new_instance,
         status_params
       ) do
    case StatusStorage.apply_status_with_entry(
           unit_type,
           unit_id,
           status_id,
           [
             val1: new_instance.val1,
             val2: new_instance.val2,
             val3: new_instance.val3,
             val4: new_instance.val4,
             tick: instance.tick,
             flag: instance.flag,
             duration: duration,
             caster_id: instance.source_id,
             source_type: instance.source_type,
             state: new_instance.state || %{},
             phase: new_instance.phase
           ] ++ Keyword.take(status_params, [:first_tick]),
           store_decision(definition, {unit_type, unit_id}, held, incoming, new_instance)
         ) do
      {:stored, stored_instance, prior_instance} ->
        StatusTickManager.arm(unit_type, unit_id, stored_instance)

        finish_stored_application(
          unit_type,
          unit_id,
          status_id,
          stored_instance,
          prior_instance,
          definition,
          status_params
        )

      {:superseded, _current} ->
        cleanup_unstored_application(unit_type, unit_id, definition, new_instance)

      {:kept, _current} ->
        cleanup_unstored_application(unit_type, unit_id, definition, new_instance)
        end_ended_on_start(unit_type, unit_id, status_id, definition)
    end
  end

  defp finish_stored_application(
         unit_type,
         unit_id,
         status_id,
         stored_instance,
         prior_instance,
         definition,
         status_params
       ) do
    {same_status, same_events} =
      reconcile_replaced_same_status(
        unit_type,
        unit_id,
        status_id,
        stored_instance,
        prior_instance,
        definition
      )

    if same_status == :current do
      {outcome, events} =
        reconcile_replaced_statuses(unit_type, unit_id, status_id, stored_instance, definition)

      result =
        if outcome == :current,
          do: finish_application(unit_type, unit_id, status_id, stored_instance, status_params),
          else: :ok

      prepend_events(result, same_events ++ events)
    else
      {:ok, same_events}
    end
  end

  defp cleanup_unstored_application(unit_type, unit_id, definition, instance) do
    context =
      ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

    definition.module.on_expire({unit_type, unit_id}, instance, context)
    :ok
  end

  defp finish_application(unit_type, unit_id, status_id, stored_instance, _status_params) do
    case StartChecks.ensure_living_target(unit_type, unit_id) do
      :ok ->
        if StatusStorage.get_status(unit_type, unit_id, status_id) === stored_instance do
          StatusDisplay.on_applied(unit_type, unit_id, status_id, stored_instance)
          Notifications.notify_unit_status_applied(unit_type, unit_id, status_id)

          {:ok, [{status_id, :apply}]}
        else
          :ok
        end

      {:error, :target_dead} = error ->
        rollback_application(unit_type, unit_id, status_id, stored_instance)
        error
    end
  end

  defp rollback_application(unit_type, unit_id, status_id, stored_instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, stored_instance) do
      undo_status_entry(unit_type, unit_id, status_id, stored_instance)
    end

    :ok
  end

  defp discard_application(unit_type, unit_id, status_id, stored_instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, stored_instance) do
      undo_status_entry(unit_type, unit_id, status_id, stored_instance)
    end

    :ok
  end

  # An application that never started (rolled back or superseded) is undone
  # without ending its end-on-end statuses: a failed start never ended anything.
  defp undo_status_entry(unit_type, unit_id, status_id, instance) do
    %{module: module} = Registry.get_definition(status_id)
    context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

    module.on_expire({unit_type, unit_id}, instance, context)

    if is_nil(StatusStorage.get_status(unit_type, unit_id, status_id)),
      do: StatusDisplay.on_removed(unit_type, unit_id, status_id, instance)
  end

  defp reconcile_replaced_statuses(unit_type, unit_id, status_id, stored_instance, definition) do
    definition.end_on_start
    |> Enum.reject(&(&1 == status_id))
    |> do_reconcile_replaced_statuses(unit_type, unit_id, status_id, stored_instance)
  end

  defp reconcile_replaced_same_status(
         unit_type,
         unit_id,
         status_id,
         stored_instance,
         prior_instance,
         definition
       ) do
    if status_id in definition.end_on_start and not is_nil(prior_instance) do
      expire_replaced_status_entry(unit_type, unit_id, status_id, prior_instance)
      Notifications.notify_mob_status_write(unit_type, unit_id, status_id, :removed)

      if StatusStorage.get_status(unit_type, unit_id, status_id) === stored_instance,
        do: {:current, [{status_id, :removed}]},
        else: {:superseded, []}
    else
      {:current, []}
    end
  end

  defp expire_replaced_status_entry(unit_type, unit_id, status_id, instance) do
    %{module: module} = Registry.get_definition(status_id)
    context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

    module.on_expire({unit_type, unit_id}, instance, context)
  end

  defp do_reconcile_replaced_statuses(
         replaced_status_ids,
         unit_type,
         unit_id,
         status_id,
         stored_instance
       ) do
    if StatusStorage.get_status(unit_type, unit_id, status_id) === stored_instance do
      reconcile_replaced_status_ids(
        replaced_status_ids,
        unit_type,
        unit_id,
        status_id,
        stored_instance
      )
    else
      {:superseded, []}
    end
  end

  defp reconcile_replaced_status_ids([], unit_type, unit_id, status_id, stored_instance) do
    if StatusStorage.get_status(unit_type, unit_id, status_id) === stored_instance,
      do: {:current, []},
      else: {:superseded, []}
  end

  defp reconcile_replaced_status_ids(
         [replaced_status_id | rest],
         unit_type,
         unit_id,
         status_id,
         stored_instance
       ) do
    case StatusStorage.get_status(unit_type, unit_id, replaced_status_id) do
      nil ->
        reconcile_replaced_status_ids(rest, unit_type, unit_id, status_id, stored_instance)

      %StatusEntry{generation: generation}
      when is_integer(generation) and generation > stored_instance.generation ->
        discard_application(unit_type, unit_id, status_id, stored_instance)
        {:superseded, []}

      replaced_instance ->
        events =
          Removal.expire_status_events_if_current(
            unit_type,
            unit_id,
            replaced_status_id,
            replaced_instance
          )

        {outcome, later_events} =
          reconcile_replaced_status_ids(
            [replaced_status_id | rest],
            unit_type,
            unit_id,
            status_id,
            stored_instance
          )

        {outcome, events ++ later_events}
    end
  end
end
