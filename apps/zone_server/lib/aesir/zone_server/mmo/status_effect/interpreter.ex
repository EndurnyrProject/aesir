defmodule Aesir.ZoneServer.Mmo.StatusEffect.Interpreter do
  @moduledoc """
  Core engine for status effects.

  Status effects are plain Elixir modules implementing
  `Aesir.ZoneServer.Mmo.StatusEffect.Definition`, registered in
  `Aesir.ZoneServer.Mmo.StatusEffect.Effects`. This module drives their lifecycle:

  1. `apply_status/4` checks immunity, prevention, conflicts and resistance
     from the status metadata, then runs the module's `on_apply` callback and
     stores the instance. An `on_apply` returning `:remove` vetoes the
     application (e.g. Blessing being consumed as a cure).
  2. `process_tick/3` runs `on_tick` for periodic behavior.
  3. `on_damage/3` notifies every active status that the unit took damage.
  4. `remove_status/3` runs `on_expire` and deletes the instance.
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.TargetState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type unit_type :: Unit.unit_type()

  @doc """
  Initializes the status effect system by loading all definitions.
  """
  @spec init() :: :ok
  def init do
    Registry.load_definitions()
  end

  @doc """
  Applies a status effect to a unit.

  Returns `:ok` on success (including when the effect's `on_apply` consumed
  the application), or `{:error, reason}` when the status is unknown or the
  target is immune, protected or resisted it.

  A boss-flagged target rejects every status that did not originate from itself
  with `{:error, :boss_immune}`. Self-origin must be positively identified: the
  caster id has to equal the target's id and its type, resolved through
  `StatusEntry.resolve_source_type/4`, has to match the target's. An application
  carrying no caster identity at all is therefore external, which is what blocks
  the offensive skills that apply crowd control without naming their caster.

  Passing `loaded: true` (rAthena `SCFLAG_LOADED`) marks the application as
  the restore of a persisted status: it already passed every gate when first
  applied, so immunity, prevention, conflict and resistance checks are
  skipped and the given `duration` is used as-is.

  A skill may pass `success_rate` and `resistance_roll` to combine its base
  application chance with status resistance in one injectable final roll.
  """
  @spec apply_status(unit_type(), integer(), atom(), StatusEntry.status_params()) ::
          :ok | {:error, atom()}
  def apply_status(unit_type, unit_id, status_id, status_params \\ []) do
    case Registry.get_definition(status_id) do
      nil ->
        Logger.warning("Unknown status effect: #{status_id}")
        {:error, :unknown_status}

      definition ->
        apply_known_status(unit_type, unit_id, status_id, status_params, definition)
    end
  end

  defp apply_known_status(unit_type, unit_id, status_id, status_params, definition) do
    with :ok <- ensure_living_target(unit_type, unit_id) do
      if Keyword.get(status_params, :loaded, false) do
        apply_loaded_status(unit_type, unit_id, status_id, status_params, definition)
      else
        apply_new_status(unit_type, unit_id, status_id, status_params, definition)
      end
    end
  end

  defp apply_new_status(unit_type, unit_id, status_id, status_params, definition) do
    entity_info = get_entity_info(unit_type, unit_id)
    duration_override = Keyword.get(status_params, :duration)

    with :ok <- check_immunity(entity_info, definition),
         :ok <- check_boss_immunity(entity_info, unit_type, unit_id, status_params),
         :ok <- check_prevented(unit_type, unit_id, definition),
         :ok <- check_conflicts(unit_type, unit_id, definition),
         {:ok, duration} <-
           roll_resistance(status_id, definition, entity_info, duration_override, status_params) do
      end_replaced_statuses(unit_type, unit_id, definition)
      create_and_store(unit_type, unit_id, status_id, status_params, definition, duration)
    end
  end

  defp apply_loaded_status(unit_type, unit_id, status_id, status_params, definition) do
    duration = if definition.permanent, do: nil, else: Keyword.get(status_params, :duration)
    end_replaced_statuses(unit_type, unit_id, definition)
    create_and_store(unit_type, unit_id, status_id, status_params, definition, duration)
  end

  @doc """
  Runs the on_tick callback for an active status.
  """
  @spec process_tick(unit_type(), integer(), atom()) :: :ok
  def process_tick(unit_type, unit_id, status_id) do
    with_active_status(unit_type, unit_id, status_id, fn module, instance, context ->
      case module.on_tick({unit_type, unit_id}, instance, context) do
        {:ok, new_instance} ->
          store_instance_changes(unit_type, unit_id, status_id, new_instance)

        :remove ->
          remove_status(unit_type, unit_id, status_id)

        {:error, reason} ->
          Logger.warning("Status #{status_id} on_tick failed: #{inspect(reason)}")
          :ok
      end
    end)
  end

  @doc """
  Notifies all active statuses on a unit that it took damage.

  `damage_info` is a map with at least `:damage` and `:element`; the player
  damage path also populates `:hp_after` and `:max_hp`. An `on_damage` callback
  may request follow-up status applications; they are drained after every active
  status has been notified.
  """
  @spec on_damage(unit_type(), integer(), map()) :: :ok
  def on_damage(unit_type, unit_id, damage_info) do
    follow_ups =
      unit_type
      |> StatusStorage.get_unit_statuses(unit_id)
      |> Enum.flat_map(fn instance ->
        dispatch_damage(unit_type, unit_id, instance, damage_info)
      end)

    Enum.each(follow_ups, fn {status_id, params} ->
      apply_status(unit_type, unit_id, status_id, params)
    end)
  end

  @doc """
  Notifies the attacker's implementing statuses that one of its weapon hits landed.

  Only statuses implementing `c:Definition.on_dealt_damage/4` are dispatched -
  the registry indexes them, so an attacker holding none (and, today, every
  attacker) costs one registry read and nothing else. Status follow-ups are
  applied here; `{:auto_cast, ...}` follow-ups are returned for the combat path
  to drain once the triggering hit has settled.
  """
  @spec on_dealt_damage(unit_type(), integer(), map()) :: [Definition.auto_cast()]
  def on_dealt_damage(unit_type, unit_id, hit_info) do
    implementing = Registry.statuses_implementing(:on_dealt_damage)

    if MapSet.size(implementing) == 0 do
      []
    else
      {auto_casts, status_follow_ups} =
        unit_type
        |> StatusStorage.get_unit_statuses(unit_id)
        |> Enum.filter(&MapSet.member?(implementing, &1.type))
        |> Enum.flat_map(&dispatch_dealt_damage(unit_type, unit_id, &1, hit_info))
        |> Enum.split_with(&match?({:auto_cast, _, _, _}, &1))

      Enum.each(status_follow_ups, fn {status_id, params} ->
        apply_status(unit_type, unit_id, status_id, params)
      end)

      auto_casts
    end
  end

  @doc "Notifies active statuses that their holder made movement contact with a unit."
  @spec on_movement_contact(unit_type(), integer(), {unit_type(), integer()}) :: :ok
  def on_movement_contact(unit_type, unit_id, contact) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.each(&dispatch_contact(unit_type, unit_id, &1, contact))
  end

  @doc """
  Folds the target's active statuses over an incoming hit before HP is reduced.

  Each status' `absorb_damage` callback sees the running `damage` (already reduced
  by statuses folded before it) inside `hit_info` and may lower it. Returning
  `:remove` passes the hit through and expires the status; `{:remove, damage}`
  expires it after setting the running damage. Updated state is persisted and
  removals run the expire path. Returns the final integer damage.
  """
  @spec absorb_damage(unit_type(), integer(), integer(), map()) :: integer()
  def absorb_damage(unit_type, unit_id, damage, hit_info) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.reduce(damage, fn instance, acc ->
      dispatch_absorb(unit_type, unit_id, instance, acc, hit_info)
    end)
  end

  @doc """
  Removes a status effect, running its on_expire callback first.
  """
  @spec remove_status(unit_type(), integer(), atom()) :: :ok
  def remove_status(unit_type, unit_id, status_id) do
    with_active_status(unit_type, unit_id, status_id, fn module, instance, context ->
      module.on_expire({unit_type, unit_id}, instance, context)
      StatusStorage.remove_status(unit_type, unit_id, status_id)
      StatusDisplay.on_removed(unit_type, unit_id, status_id, instance)
      :ok
    end)
  end

  @doc """
  Toggles a status effect on a unit.

  If the status is currently active, removes it and returns `{:ok, :removed}`.
  If the status is not active, applies it and returns `{:ok, :applied}`.
  On application failure, propagates `{:error, reason}` unchanged.
  """
  @spec toggle_status(unit_type(), integer(), atom(), StatusEntry.status_params()) ::
          {:ok, :applied | :removed} | {:error, atom()}
  def toggle_status(unit_type, unit_id, status_id, params \\ []) do
    if StatusStorage.has_status?(unit_type, unit_id, status_id) do
      remove_status(unit_type, unit_id, status_id)
      {:ok, :removed}
    else
      case apply_status(unit_type, unit_id, status_id, params) do
        :ok -> {:ok, :applied}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Returns the aggregated stat modifiers from all active statuses on a unit.
  """
  @spec get_all_modifiers(unit_type(), integer()) :: map()
  def get_all_modifiers(unit_type, unit_id) do
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  @doc """
  Checks if a status has a specific property.
  """
  @spec has_property?(atom(), atom()) :: boolean()
  defdelegate has_property?(status_id, property), to: PropertyChecker

  @doc """
  Checks if a status is a debuff.
  """
  @spec debuff?(atom()) :: boolean()
  defdelegate debuff?(status_id), to: PropertyChecker

  @doc """
  Checks if a status is a buff.
  """
  @spec buff?(atom()) :: boolean()
  defdelegate buff?(status_id), to: PropertyChecker

  @doc """
  Checks if a status prevents movement.
  """
  @spec prevents_movement?(atom()) :: boolean()
  defdelegate prevents_movement?(status_id), to: PropertyChecker

  @doc """
  Checks if a status prevents skill usage.
  """
  @spec prevents_skills?(atom()) :: boolean()
  defdelegate prevents_skills?(status_id), to: PropertyChecker

  @doc """
  Checks if a status prevents attacking.
  """
  @spec prevents_attack?(atom()) :: boolean()
  defdelegate prevents_attack?(status_id), to: PropertyChecker

  @doc """
  Returns all properties of a status.
  """
  @spec get_properties(atom()) :: [atom()]
  defdelegate get_properties(status_id), to: PropertyChecker

  @doc """
  Returns whether a unit may move, i.e. carries no `prevents_movement` status.
  """
  @spec can_move?(unit_type(), integer()) :: boolean()
  def can_move?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &prevents_movement?/1)

  @doc """
  Returns whether a unit may attack, i.e. carries no `prevents_attack` status.
  """
  @spec can_attack?(unit_type(), integer()) :: boolean()
  def can_attack?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &prevents_attack?/1)

  @doc """
  Returns whether a unit may use skills, i.e. carries no `prevents_skills` status.
  """
  @spec can_use_skill?(unit_type(), integer()) :: boolean()
  def can_use_skill?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &prevents_skills?/1)

  @doc """
  Returns whether a unit may cast a specific skill.

  Like `can_use_skill?/2`, but a `prevents_skills` status does not block a skill
  it lists in `:allow_skills`. This lets a feigning-death player recast
  NV_TRICKDEAD to stand back up even though SC_TRICKDEAD prevents skills.
  """
  @spec can_use_skill?(unit_type(), integer(), integer()) :: boolean()
  def can_use_skill?(unit_type, unit_id, skill_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(fn %StatusEntry{type: type} ->
      not prevents_skills?(type) or skill_id in PropertyChecker.allowed_skills(type)
    end)
  end

  @doc """
  Returns whether a unit may be targeted, i.e. carries no `untargetable` status.
  """
  @spec targetable?(unit_type(), integer()) :: boolean()
  def targetable?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.untargetable?/1)

  @doc """
  Returns whether a unit is concealed, i.e. carries a status with the
  `:conceals` property (Hiding or Cloaking).

  Deliberately separate from `targetable?/2`, which has callers outside mob
  AI; changing it would silently alter player targeting and skill targeting.
  """
  @spec concealed?(unit_type(), integer()) :: boolean()
  def concealed?(unit_type, unit_id),
    do: restricted?(unit_type, unit_id, &PropertyChecker.has_property?(&1, :conceals))

  defp restricted?(unit_type, unit_id, pred) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.any?(fn %StatusEntry{type: type} -> pred.(type) end)
  end

  defp check_immunity(entity_info, definition) do
    if PropertyChecker.check_immunity(entity_info, definition) do
      {:error, :immune}
    else
      :ok
    end
  end

  defp check_boss_immunity(%{boss_flag: true}, unit_type, unit_id, status_params) do
    {_val1, _val2, _val3, _val4, _tick, _flag, caster_id, _duration, _state, _phase} =
      StatusEntry.extract_params(status_params)

    source_type = StatusEntry.resolve_source_type(unit_type, unit_id, caster_id, status_params)

    if source_type == unit_type and caster_id == unit_id do
      :ok
    else
      {:error, :boss_immune}
    end
  end

  defp check_boss_immunity(_entity_info, _unit_type, _unit_id, _status_params), do: :ok

  defp check_prevented(unit_type, unit_id, definition) do
    if any_status_active?(unit_type, unit_id, definition.prevented_by) do
      {:error, :prevented}
    else
      :ok
    end
  end

  defp check_conflicts(unit_type, unit_id, definition) do
    if any_status_active?(unit_type, unit_id, definition.conflicts_with) do
      {:error, :conflict}
    else
      :ok
    end
  end

  defp any_status_active?(unit_type, unit_id, status_ids) do
    Enum.any?(status_ids, &StatusStorage.has_status?(unit_type, unit_id, &1))
  end

  defp roll_resistance(_status_id, %{permanent: true}, _entity_info, _duration_override, _params),
    do: {:ok, nil}

  defp roll_resistance(status_id, definition, entity_info, duration_override, status_params) do
    base_duration = duration_override || definition.duration || 10_000
    base_success_rate = Keyword.get(status_params, :success_rate, 100)
    resistance_roll = Keyword.get(status_params, :resistance_roll, &Resistance.roll_success/1)

    {success_rate, adjusted_duration} =
      if Resistance.should_apply_resistance?(definition) do
        Resistance.apply_resistance(
          definition,
          entity_info[:stats] || %{},
          base_success_rate,
          base_duration
        )
      else
        {base_success_rate, base_duration}
      end

    success_rate = apply_res_eff_tolerance(success_rate, entity_info, status_id, status_params)

    if resistance_roll.(success_rate) do
      {:ok, adjusted_duration}
    else
      {:error, :resisted}
    end
  end

  # Equipment `bResEff` tolerance (per-10000) subtracts from the final infliction
  # rate before the roll, floored at zero. The target's equipment slice rides its
  # published UnitRegistry entry (`entity_info[:equip_modifiers]`), so this reaches
  # every infliction source without a call into the target's session. Mobs and
  # players without the key are unaffected. Callers that already subtracted the
  # tolerance at their own roll (item on-hit procs) pass `res_eff_exempt: true`
  # so the reduction applies exactly once per infliction.
  defp apply_res_eff_tolerance(success_rate, entity_info, status_id, status_params) do
    if Keyword.get(status_params, :res_eff_exempt, false) do
      success_rate
    else
      tolerance =
        entity_info
        |> Map.get(:equip_modifiers, %{})
        |> Map.get({:res_eff, status_id}, 0)

      max(success_rate - tolerance / 100, 0)
    end
  end

  defp end_replaced_statuses(unit_type, unit_id, definition) do
    Enum.each(definition.end_on_start, fn status_id ->
      if StatusStorage.has_status?(unit_type, unit_id, status_id) do
        remove_status(unit_type, unit_id, status_id)
      end
    end)
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
      next_tick_at: if(tick > 0, do: now_ms + tick, else: nil),
      tick_count: 0,
      expires_at: nil
    }

    context = ContextBuilder.build_context(unit_type, unit_id, caster_id, instance)

    case definition.module.on_apply({unit_type, unit_id}, instance, context) do
      {:ok, new_instance} ->
        StatusStorage.apply_status(unit_type, unit_id, status_id,
          val1: val1,
          val2: val2,
          val3: val3,
          val4: val4,
          tick: tick,
          flag: flag,
          duration: duration,
          caster_id: caster_id,
          source_type: source_type,
          state: new_instance.state || %{},
          phase: new_instance.phase
        )

        stored_instance = StatusStorage.get_status(unit_type, unit_id, status_id)
        StatusDisplay.on_applied(unit_type, unit_id, status_id, stored_instance)

        :ok

      :remove ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_tick(tick, _definition) when tick > 0, do: tick
  defp resolve_tick(_tick, %{tick_interval: interval}) when is_integer(interval), do: interval
  defp resolve_tick(tick, _definition), do: tick

  defp dispatch_damage(unit_type, unit_id, instance, damage_info),
    do: dispatch_hook(:on_damage, unit_type, unit_id, instance, damage_info)

  defp dispatch_dealt_damage(unit_type, unit_id, instance, hit_info),
    do: dispatch_hook(:on_dealt_damage, unit_type, unit_id, instance, hit_info)

  # Shared body of the two damage-driven hooks: both take the event map as their
  # third argument and return follow-ups for their caller to drain.
  defp dispatch_hook(hook, unit_type, unit_id, instance, event) do
    case Registry.get_definition(instance.type) do
      nil ->
        []

      definition ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

        case apply(definition.module, hook, [{unit_type, unit_id}, instance, event, context]) do
          {:ok, new_instance} ->
            store_instance_changes(unit_type, unit_id, instance.type, new_instance)
            []

          {:ok, new_instance, follow_ups} ->
            store_instance_changes(unit_type, unit_id, instance.type, new_instance)
            follow_ups

          :remove ->
            remove_status(unit_type, unit_id, instance.type)
            []

          {:error, reason} ->
            Logger.warning("Status #{instance.type} #{hook} failed: #{inspect(reason)}")
            []
        end
    end
  end

  defp dispatch_contact(unit_type, unit_id, instance, contact) do
    case Registry.get_definition(instance.type) do
      nil ->
        :ok

      definition ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

        case definition.module.on_contact({unit_type, unit_id}, instance, contact, context) do
          {:ok, new_instance} ->
            store_instance_changes(unit_type, unit_id, instance.type, new_instance)

          :remove ->
            remove_status(unit_type, unit_id, instance.type)

          {:error, reason} ->
            Logger.warning("Status #{instance.type} on_contact failed: #{inspect(reason)}")
        end
    end
  end

  defp dispatch_absorb(unit_type, unit_id, instance, damage, hit_info) do
    case Registry.get_definition(instance.type) do
      nil ->
        damage

      definition ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)
        hit_info = Map.put(hit_info, :damage, damage)

        case definition.module.absorb_damage({unit_type, unit_id}, instance, hit_info, context) do
          {:ok, new_damage, new_instance} ->
            store_instance_changes(unit_type, unit_id, instance.type, new_instance)
            new_damage

          :remove ->
            remove_status(unit_type, unit_id, instance.type)
            damage

          {:remove, new_damage} ->
            remove_status(unit_type, unit_id, instance.type)
            new_damage
        end
    end
  end

  defp store_instance_changes(unit_type, unit_id, status_id, new_instance) do
    StatusStorage.update_status(unit_type, unit_id, status_id, fn entry ->
      %{entry | state: new_instance.state || %{}, phase: new_instance.phase}
    end)

    :ok
  end

  defp with_active_status(unit_type, unit_id, status_id, fun) do
    with definition when definition != nil <- Registry.get_definition(status_id),
         instance when instance != nil <- StatusStorage.get_status(unit_type, unit_id, status_id) do
      context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)
      fun.(definition.module, instance, context)
    else
      _ -> :ok
    end

    :ok
  end

  defp get_entity_info(unit_type, unit_id) do
    case UnitRegistry.get_unit_info(unit_type, unit_id) do
      {:ok, entity_info} ->
        entity_info

      {:error, :not_found} ->
        raise "Cannot apply status effect to non-existent #{unit_type} with ID: #{unit_id}"
    end
  end

  defp ensure_living_target(unit_type, unit_id) when unit_type in [:player, :mob] do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, target_state, _pid}} ->
        if TargetState.living?(target_state), do: :ok, else: {:error, :target_dead}

      {:error, :not_found} ->
        :ok
    end
  end

  defp ensure_living_target(_unit_type, _unit_id), do: :ok
end
