defmodule Aesir.ZoneServer.Mmo.StatusEffect.Interpreter do
  @moduledoc """
  Core engine for status effects.

  Status effects are plain Elixir modules implementing
  `Aesir.ZoneServer.Mmo.StatusEffect.Definition`, registered in
  `Aesir.ZoneServer.Mmo.StatusEffect.Effects`. This module drives their lifecycle:

  1. `apply_status/4` checks status immunity, equipment magic immunity
     (`{:error, :magic_immune}`), boss immunity, prevention, conflicts and
     resistance, then runs the module's `on_apply` callback and stores the
     instance. An `on_apply` returning `:remove` vetoes the
     application (e.g. Blessing being consumed as a cure).
  2. `process_tick/3` runs `on_tick` for periodic behavior.
  3. `on_damage/3` notifies every active status that the unit took damage.
  4. `remove_status/3` runs `on_expire` and deletes the instance.
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition, as: SkillDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @type unit_type :: Unit.unit_type()
  @type remove_option :: {:owner_refresh, StatusEntry.owner_refresh()}

  # Damage stages, each status at the step the reference applies it (see
  # absorb_damage/4). Common arithmetic runs every listed step; blocking stops at
  # the first step that leaves no damage.
  @common_stage [
    :sc_aeterna,
    :sc_raid,
    :sc_assumptio,
    :sc_defender,
    :sc_fogwall,
    :sc_energycoat,
    :sc_steelbody
  ]
  @block_stage [:sc_kyrie, :sc_safetywall, :sc_pneuma, :sc_basilica, :sc_basilica_caster]
  # NOTE: interim placement after every reduction and block. Magic Rod moves to
  # same-source magic interception and Wink Charm to the damage notification.
  @after_stage [:sc_magicrod, :sc_winkcharm]

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
  skipped and the given `duration` is used as-is. A loaded finite definition
  requires a positive integer duration.

  `owner_refresh: :notify` publishes an asynchronous player stat refresh only
  after the status is stored. Applications default to `:auto`: the owning
  session's handlers recalculate synchronously, so an application made from
  that session defers, while one made from any other process (another player's
  cast, a mob, a manager) notifies the owner.

  A skill may pass `success_rate` and `resistance_roll` to combine its base
  application chance with status resistance in one injectable final roll.
  `bypass_resistance: true` skips that roll and all chance/stat/duration
  resistance while retaining immunity, prevention, and conflict gates.
  `no_avoid: true` additionally skips the immunity gates (race, element, boss and
  magic immunity): the application cannot be avoided, only prevented.

  When a status listed in the definition's `end_return` is active, the
  application ends every such status instead and returns `:ok` without storing.
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
    with :ok <- ensure_eligible_target(unit_type, definition),
         :ok <- ensure_living_target(unit_type, unit_id),
         :ok <- ensure_status_allowed(unit_type, unit_id, status_id) do
      if Keyword.get(status_params, :loaded, false) do
        apply_loaded_status(unit_type, unit_id, status_id, status_params, definition)
      else
        apply_new_status(unit_type, unit_id, status_id, status_params, definition)
      end
    end
  end

  defp ensure_status_allowed(unit_type, unit_id, :sc_endure) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, %{map_name: map_name}, _pid}} ->
        if Rules.status_allowed?(:sc_endure, map_name),
          do: :ok,
          else: {:error, :status_not_allowed}

      {:error, :not_found} ->
        :ok
    end
  end

  defp ensure_status_allowed(_unit_type, _unit_id, _status_id), do: :ok

  # Reference order (status_change_start): magic and boss immunity (BossResist),
  # then EndReturn, then the Fail list and the race/element immunity before resistance.
  defp apply_new_status(unit_type, unit_id, status_id, status_params, definition) do
    entity_info = get_entity_info(unit_type, unit_id)

    with :ok <- check_resisted(entity_info, unit_type, unit_id, status_params, definition) do
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
          remove_statuses(unit_type, unit_id, active)
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

    with :ok <- check_avoidable(entity_info, status_params, definition),
         :ok <- check_prevented(unit_type, unit_id, definition),
         :ok <- check_conflicts(unit_type, unit_id, definition),
         {:ok, duration} <-
           roll_resistance(
             unit_type,
             unit_id,
             status_id,
             definition,
             entity_info,
             duration_override,
             status_params
           ) do
      create_and_store(unit_type, unit_id, status_id, status_params, definition, duration)
    end
  end

  defp check_resisted(entity_info, unit_type, unit_id, status_params, definition) do
    if Keyword.get(status_params, :no_avoid, false) do
      :ok
    else
      with :ok <- check_magic_immunity(unit_type, unit_id),
           :ok <- check_immunity(entity_info, immunities(definition, &(&1 == :boss))) do
        check_boss_immunity(entity_info, unit_type, unit_id, status_params, definition)
      end
    end
  end

  defp check_avoidable(entity_info, status_params, definition) do
    if Keyword.get(status_params, :no_avoid, false),
      do: :ok,
      else: check_immunity(entity_info, immunities(definition, &(&1 != :boss)))
  end

  defp immunities(definition, keep?),
    do: %{definition | immunity: Enum.filter(definition.immunity, keep?)}

  defp apply_loaded_status(unit_type, unit_id, status_id, status_params, definition) do
    with {:ok, duration} <- loaded_duration(definition, status_params) do
      create_and_store(unit_type, unit_id, status_id, status_params, definition, duration)
    end
  end

  defp loaded_duration(%{permanent: true}, _status_params), do: {:ok, nil}

  defp loaded_duration(_definition, status_params) do
    case Keyword.get(status_params, :duration) do
      duration when is_integer(duration) and duration > 0 -> {:ok, duration}
      _invalid -> {:error, :invalid_duration}
    end
  end

  @doc """
  Runs the on_tick callback for an active status.
  """
  @spec process_tick(unit_type(), integer(), atom()) :: :ok
  def process_tick(unit_type, unit_id, status_id) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{generation: generation} when is_integer(generation) ->
        process_tick_if_current(unit_type, unit_id, status_id, generation)
        :ok

      _missing ->
        :ok
    end
  end

  @doc """
  Runs an exact tick only when the expected status generation is still current.

  Returns `:continue` when the callback retained the current status, otherwise
  returns `:stop` so an exact-timer owner does not schedule another deadline.
  """
  @spec process_tick_if_current(unit_type(), integer(), atom(), pos_integer()) ::
          :continue | :stop
  def process_tick_if_current(unit_type, unit_id, status_id, expected_generation) do
    with %{module: module} when not is_nil(module) <- Registry.get_definition(status_id),
         %StatusEntry{generation: ^expected_generation} = instance <-
           StatusStorage.get_status(unit_type, unit_id, status_id) do
      case UnitRegistry.get_unit_info(unit_type, unit_id) do
        {:ok, %{stats: target_stats}} when not is_nil(target_stats) ->
          process_current_exact_tick(
            module,
            unit_type,
            unit_id,
            status_id,
            expected_generation,
            instance,
            target_stats
          )

        unexpected ->
          Logger.warning(
            "Stopping exact tick for #{status_id}: invalid #{unit_type} #{unit_id} lookup #{inspect(unexpected)}"
          )

          StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance)
          :stop
      end
    else
      _ -> :stop
    end
  end

  defp process_current_exact_tick(
         module,
         unit_type,
         unit_id,
         status_id,
         expected_generation,
         instance,
         target_stats
       ) do
    context =
      ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance, target_stats)

    case module.on_tick({unit_type, unit_id}, instance, context) do
      {:ok, new_instance} ->
        store_instance_changes_if_current(
          unit_type,
          unit_id,
          status_id,
          expected_generation,
          new_instance
        )

        :continue

      :remove ->
        expire_status_if_current(unit_type, unit_id, status_id, instance)
        :stop

      {:error, reason} ->
        Logger.warning("Status #{status_id} exact on_tick failed: #{inspect(reason)}")
        :stop
    end
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
  Dispatches the target's interception-capable statuses before a weapon hit
  selects a replacement or resolves damage.

  Each capable status may atomically consume a single-use entry of the target
  and return `{:intercept, result}`; the first interception wins and ends the
  swing. A target holding no such status stays on a constant-time no-op path.
  """
  @spec before_weapon_hit(unit_type(), integer(), map()) :: :continue | {:intercept, term()}
  def before_weapon_hit(unit_type, unit_id, attack_info) do
    implementing = Registry.statuses_implementing(:before_weapon_hit)

    if MapSet.size(implementing) == 0 do
      :continue
    else
      find_weapon_hit_interception(unit_type, unit_id, implementing, attack_info)
    end
  end

  @doc """
  Atomically claims one bounded modifier for the attacker's ordinary swing.

  The callback result is exposed only after the captured status generation was
  removed successfully. An attacker holding no implementing status stays on a
  constant-time registry-read no-op path.
  """
  @spec before_normal_attack(unit_type(), integer(), map()) ::
          Definition.normal_attack_modifier() | nil
  def before_normal_attack(unit_type, unit_id, attack_info) do
    :before_normal_attack
    |> Registry.statuses_implementing()
    |> Enum.find_value(fn status_id ->
      case StatusStorage.get_status(unit_type, unit_id, status_id) do
        nil -> nil
        instance -> claim_normal_attack_modifier(unit_type, unit_id, instance, attack_info)
      end
    end)
  end

  @doc """
  Asks the attacker's statuses to replace its pending ordinary swing.

  Returns the first `{:skill_attack, opts}` produced by a status implementing
  `c:Definition.attack_replacement/3`, or `:normal`. Only indexed implementers
  are dispatched, so an attacker holding none costs one registry read.
  """
  @spec attack_replacement(unit_type(), integer()) :: Definition.attack_replacement_result()
  def attack_replacement(unit_type, unit_id) do
    implementing = Registry.statuses_implementing(:attack_replacement)

    if MapSet.size(implementing) == 0 do
      :normal
    else
      unit_type
      |> StatusStorage.get_unit_statuses(unit_id)
      |> Enum.filter(&MapSet.member?(implementing, &1.type))
      |> Enum.find_value(:normal, &dispatch_attack_replacement(unit_type, unit_id, &1))
    end
  end

  defp dispatch_attack_replacement(unit_type, unit_id, instance) do
    with %{module: module} <- Registry.get_definition(instance.type) do
      context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

      case module.attack_replacement({unit_type, unit_id}, instance, context) do
        :normal ->
          nil

        {:skill_attack, opts} = replacement when is_list(opts) ->
          replacement

        result ->
          raise "invalid attack_replacement result for #{instance.type}: #{inspect(result)}"
      end
    end
  end

  @doc """
  Notifies the attacker's implementing statuses that one of its weapon hits landed.

  Only statuses implementing `c:Definition.on_dealt_damage/4` are dispatched -
  the registry indexes them, so an attacker holding none costs one registry
  read and nothing else. Status follow-ups are applied here; typed combat
  follow-ups are returned for the attacker's own combat path to settle.
  """
  @spec on_dealt_damage(unit_type(), integer(), map()) ::
          [Definition.auto_cast() | Definition.local_heal()]
  def on_dealt_damage(unit_type, unit_id, hit_info) do
    implementing = Registry.statuses_implementing(:on_dealt_damage)

    if MapSet.size(implementing) == 0 do
      []
    else
      {combat_follow_ups, status_follow_ups} =
        unit_type
        |> StatusStorage.get_unit_statuses(unit_id)
        |> Enum.filter(&MapSet.member?(implementing, &1.type))
        |> Enum.flat_map(&dispatch_dealt_damage(unit_type, unit_id, &1, hit_info))
        |> Enum.split_with(&combat_follow_up?/1)

      Enum.each(status_follow_ups, fn {status_id, params} ->
        apply_status(unit_type, unit_id, status_id, params)
      end)

      combat_follow_ups
    end
  end

  @doc """
  Dispatches the victim's post-damage statuses after a delivered hit reduced HP.

  Runs inside the attacker's process. Every status on the victim implementing
  `c:Definition.after_damage_taken/4` sees the delivered `hit_info` (carrying the
  final `:damage`) and may return `{:reflect, amount}`; the amounts are summed
  into the total damage the caller sends back to the attacker. A victim holding
  no implementing status stays on a constant-time registry-read no-op path.
  """
  @spec after_damage_taken(unit_type(), integer(), map()) :: non_neg_integer()
  def after_damage_taken(unit_type, unit_id, hit_info) do
    implementing = Registry.statuses_implementing(:after_damage_taken)

    if MapSet.size(implementing) == 0 do
      0
    else
      unit_type
      |> StatusStorage.get_unit_statuses(unit_id)
      |> Enum.filter(&MapSet.member?(implementing, &1.type))
      |> Enum.reduce(0, fn instance, acc ->
        acc + dispatch_after_damage_taken(unit_type, unit_id, instance, hit_info)
      end)
    end
  end

  @doc """
  Dispatches a validated player action once to statuses indexed for the capability.

  Updates and removals use the captured status entry as their generation token.
  Returns `:changed` when a current entry changed, otherwise `:unchanged`.
  """
  @spec on_committed_action(unit_type(), integer(), Definition.committed_action()) ::
          :changed | :unchanged
  def on_committed_action(unit_type, unit_id, action) do
    implementing = Registry.statuses_implementing(:on_committed_action)

    Enum.reduce(implementing, :unchanged, fn status_id, result ->
      case StatusStorage.get_status(unit_type, unit_id, status_id) do
        nil -> result
        instance -> dispatch_committed_action(unit_type, unit_id, instance, action, result)
      end
    end)
  end

  @doc "Returns whether the unit has an active status indexed for `flag`."
  @spec has_active_flag?(unit_type(), integer(), atom()) :: boolean()
  def has_active_flag?(unit_type, unit_id, flag) do
    flag
    |> Registry.statuses_with_flag()
    |> Enum.any?(&StatusStorage.has_status?(unit_type, unit_id, &1))
  end

  @doc """
  Dispatches movement intent once to statuses indexed for the capability.

  Returns `:changed` only when a current-generation mutation changes status
  modifiers, allowing the owning session to perform one synchronous recalculation.
  """
  @spec on_movement_intent(unit_type(), integer(), %{map: String.t(), x: integer(), y: integer()}) ::
          :changed | :unchanged
  def on_movement_intent(unit_type, unit_id, position) do
    implementing = Registry.statuses_implementing(:on_movement_intent)

    if MapSet.size(implementing) == 0 do
      :unchanged
    else
      dispatch_movement_intents(unit_type, unit_id, implementing, position)
    end
  end

  defp dispatch_movement_intents(unit_type, unit_id, implementing, position) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&MapSet.member?(implementing, &1.type))
    |> Enum.reduce(:unchanged, fn instance, result ->
      if dispatch_movement_intent(unit_type, unit_id, instance, position),
        do: :changed,
        else: result
    end)
  end

  defp combat_follow_up?({:auto_cast, _, _, _}), do: true
  defp combat_follow_up?({:local_heal, _, _, _}), do: true
  defp combat_follow_up?(_follow_up), do: false

  @doc "Notifies active statuses that their holder made movement contact with a unit."
  @spec on_movement_contact(unit_type(), integer(), {unit_type(), integer()}) :: :ok
  def on_movement_contact(unit_type, unit_id, contact) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.each(&dispatch_contact(unit_type, unit_id, &1, contact))
  end

  @doc """
  Runs the target's damage statuses over one prepared logical hit, in the fixed
  reference order, before HP is reduced. Returns the final integer damage; a
  hit of zero damage stays zero and touches no status.

  The stages are, in order: the common damage arithmetic (Lex Aeterna, Raid,
  Assumptio, Defending Aura, Blinding Mist, Energy Coat, Mental Strength), each
  step running even when an earlier one left nothing; then, only for damage left
  above zero, the blockers (Kyrie Eleison, Safety Wall, Pneuma, Basilica),
  stopping at the first that leaves nothing. Storage order never matters.

  Status ticks and HP costs (`status_tick?: true`) are not attacks and skip both
  stages. Each callback sees the running `damage` in `hit_info`; returning
  `:remove` passes the hit through and expires the status, `{:remove, damage}`
  expires it after setting the running damage. Lex Aeterna is consumed through
  an exactly-once claim, so concurrent hits double at most once.
  """
  @spec absorb_damage(unit_type(), integer(), integer(), map()) :: integer()
  def absorb_damage(_unit_type, _unit_id, 0, _hit_info), do: 0

  def absorb_damage(unit_type, unit_id, damage, hit_info) do
    held = Map.new(StatusStorage.get_unit_statuses(unit_type, unit_id), &{&1.type, &1})
    run = &dispatch_absorb(unit_type, unit_id, Map.get(held, &1), &2, hit_info)

    damage
    |> attack_stages(Map.get(hit_info, :status_tick?, false), run)
    |> then(&Enum.reduce(@after_stage, &1, run))
  end

  @doc "Every status id with a damage stage, in stage order."
  @spec absorb_stages() :: [atom()]
  def absorb_stages, do: @common_stage ++ @block_stage ++ @after_stage

  defp attack_stages(damage, true, _run), do: damage

  defp attack_stages(damage, false, run) do
    case Enum.reduce(@common_stage, damage, run) do
      0 -> 0
      remaining -> Enum.reduce_while(@block_stage, remaining, &block_step(&1, &2, run))
    end
  end

  defp block_step(status_id, damage, run) do
    case run.(status_id, damage) do
      0 -> {:halt, 0}
      left -> {:cont, left}
    end
  end

  @doc """
  Removes a status effect, running its on_expire callback first.

  `owner_refresh: :notify` publishes the player's asynchronous refresh after a
  real removal. `owner_refresh: :defer` is for an owning session that will
  synchronously recalculate and commit the state in the same handler. The
  default `:auto` defers when the caller is the owning player process and
  notifies otherwise.
  """
  @spec remove_status(unit_type(), integer(), atom(), [remove_option()]) :: :ok
  def remove_status(unit_type, unit_id, status_id, opts \\ []) do
    removed? = remove_status_without_refresh(unit_type, unit_id, status_id)
    maybe_refresh_owner(unit_type, unit_id, removed?, opts)
  end

  @doc """
  Removes a status only while `instance` is still its current entry, through the
  normal expiration lifecycle, then applies the owner-refresh policy. Returns
  whether `instance` was removed.
  """
  @spec remove_status_if_current(unit_type(), integer(), atom(), StatusEntry.t(), [
          remove_option()
        ]) ::
          boolean()
  def remove_status_if_current(unit_type, unit_id, status_id, instance, opts \\ []) do
    removed? = expire_status_if_current(unit_type, unit_id, status_id, instance)
    maybe_refresh_owner(unit_type, unit_id, removed?, opts)
    removed?
  end

  @doc """
  Removes the supplied statuses through the normal expiration lifecycle and
  applies the selected owner-refresh policy once after the batch.
  """
  @spec remove_statuses(unit_type(), integer(), [atom()], [remove_option()]) :: :ok
  def remove_statuses(unit_type, unit_id, status_ids, opts \\ []) do
    removed? =
      Enum.reduce(status_ids, false, fn status_id, removed? ->
        remove_status_without_refresh(unit_type, unit_id, status_id) or removed?
      end)

    maybe_refresh_owner(unit_type, unit_id, removed?, opts)
  end

  defp remove_status_without_refresh(unit_type, unit_id, status_id) do
    active? =
      not is_nil(Registry.get_definition(status_id)) and
        not is_nil(StatusStorage.get_status(unit_type, unit_id, status_id))

    with_active_status(unit_type, unit_id, status_id, fn module, instance, context ->
      module.on_expire({unit_type, unit_id}, instance, context)
      StatusStorage.remove_status(unit_type, unit_id, status_id)
      StatusDisplay.on_removed(unit_type, unit_id, status_id, instance)
      notify_unit_status_removed(unit_type, unit_id, status_id)
      :ok
    end)

    active?
  end

  @doc """
  Removes finite statuses whose definitions retain the default
  `remove_on_death: true` through the normal removal lifecycle.

  Permanent statuses and explicit death-survival opt-outs remain active. The
  selected owner-refresh policy is applied once after the filtered batch.
  """
  @spec remove_on_death(unit_type(), integer(), [remove_option()]) :: :ok
  def remove_on_death(unit_type, unit_id, opts \\ []) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&remove_on_death?/1)
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, opts))
  end

  defp remove_on_death?(%StatusEntry{type: type}) do
    match?(%{permanent: false, remove_on_death: true}, Registry.get_definition(type))
  end

  @doc """
  Removes the unit's statuses flagged `remove_on_map_change` through the normal
  removal path (mirrors rAthena's `status_change_clear_onchangemap`).

  Consumed by the cross-map warp path; a status opts in via its definition's
  `:remove_on_map_change` flag, so the warp handler stays ignorant of any
  specific status.
  """
  @spec remove_on_map_change(unit_type(), integer()) :: :ok
  def remove_on_map_change(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&remove_on_map_change?/1)
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, owner_refresh: :notify))
  end

  defp remove_on_map_change?(%StatusEntry{type: type}) do
    match?(%{remove_on_map_change: true}, Registry.get_definition(type))
  end

  @doc """
  Ends every active status whose `require_weapon` list is non-empty and
  excludes `weapon_type` (mirrors rAthena's `SCF_REQUIREWEAPON`).

  Consumed by the equipment-change and job-change paths; a status opts in via
  its definition's `:require_weapon` list, so callers stay ignorant of any
  specific status.
  """
  @spec enforce_weapon_requirements(unit_type(), integer(), atom()) :: :ok
  def enforce_weapon_requirements(unit_type, unit_id, weapon_type) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&weapon_requirement_broken?(&1, weapon_type))
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, owner_refresh: :notify))
  end

  defp weapon_requirement_broken?(%StatusEntry{type: type}, weapon_type) do
    case Registry.get_definition(type) do
      %{require_weapon: [_ | _] = allowed} -> weapon_type not in allowed
      _ -> false
    end
  end

  @doc """
  Removes every active status through the normal expiration lifecycle.

  Each status receives `on_expire` and display cleanup before the selected
  owner-refresh policy is applied once for the batch.

  Passing `except_permanent: true` skips any status whose definition sets
  `permanent: true` (e.g. `SC_RIDING`, `SC_PUSHCART`): these aren't a timed
  buff to expire, they mirror an out-of-band state (a mount/cart toggle, an
  option bit) that a caller like death's cleanup must leave standing so it
  keeps surviving through the respawn that follows.
  """
  @spec remove_all_statuses(unit_type(), integer(), [
          remove_option() | {:except_permanent, boolean()}
        ]) ::
          :ok
  def remove_all_statuses(unit_type, unit_id, opts \\ []) do
    {except_permanent?, remove_opts} = Keyword.pop(opts, :except_permanent, false)

    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.reject(&(except_permanent? and permanent?(&1)))
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, remove_opts))
  end

  defp permanent?(%StatusEntry{type: type}) do
    match?(%{permanent: true}, Registry.get_definition(type))
  end

  defp maybe_refresh_owner(:player, unit_id, true, opts) do
    case Keyword.get(opts, :owner_refresh, :auto) do
      :notify -> PubSub.broadcast(Aesir.PubSub, "player:#{unit_id}", {:stats, :status_changed})
      :defer -> :ok
      :auto -> if owner_process?(unit_id), do: :ok, else: notify_player_owner(unit_id)
      policy -> raise ArgumentError, "invalid owner refresh policy: #{inspect(policy)}"
    end
  end

  defp maybe_refresh_owner(_unit_type, _unit_id, _removed?, _opts), do: :ok

  defp owner_process?(unit_id) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> pid == self()
      _ -> false
    end
  end

  defp notify_player_owner(unit_id) do
    PubSub.broadcast(Aesir.PubSub, "player:#{unit_id}", {:stats, :status_changed})
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

  Players have two entry-dependent rules: Hiding allows movement with Tunnel
  Drive, and a performance lock's root is entry-dependent. Longing frees
  ordinary ensemble performers, but not always-rooted Moonlit or Hermode.
  """
  @spec can_move?(unit_type(), integer()) :: boolean()
  def can_move?(:player, unit_id) do
    :player
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(&(not blocks_player_movement?(&1, unit_id)))
  end

  def can_move?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &prevents_movement?/1)

  @doc """
  Returns whether a unit may attack. Longing relaxes an ensemble performing
  lock, but other `prevents_attack` statuses still block attacks.
  """
  @spec can_attack?(unit_type(), integer()) :: boolean()
  def can_attack?(:player, unit_id) do
    :player
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(&(not blocks_player_attack?(&1, unit_id)))
  end

  def can_attack?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &prevents_attack?/1)

  @doc """
  Returns whether an active status blocks equipping `slot`.
  """
  @spec equip_blocked?(unit_type(), integer(), slot :: atom()) :: boolean()
  def equip_blocked?(unit_type, unit_id, slot) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.any?(fn %StatusEntry{type: type} ->
      match?(%{metadata: %{strip_slot: ^slot}}, Registry.get_definition(type))
    end)
  end

  @doc """
  Returns whether a unit may use skills, i.e. carries no `prevents_skills` status.
  """
  @spec can_use_skill?(unit_type(), integer()) :: boolean()
  def can_use_skill?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &prevents_skills?/1)

  @doc "Returns whether a unit may use items while status effects are active."
  @spec can_use_item?(unit_type(), integer()) :: boolean()
  def can_use_item?(unit_type, unit_id),
    do:
      not restricted?(unit_type, unit_id, &PropertyChecker.prevents_items?/1) and
        not channeling_gravitation?(unit_type, unit_id)

  # A pre-renewal Gravitation Field caster cannot use items; its field occupants can.
  defp channeling_gravitation?(unit_type, unit_id) do
    match?(
      %StatusEntry{state: %{self?: true}},
      StatusStorage.get_status(unit_type, unit_id, :sc_gravitation)
    )
  end

  @doc """
  Returns whether a player may sit down: no locking body state (see
  `can_stand?/1`), no performance, and not channelling a Gravitation Field.
  """
  @spec can_sit?(integer()) :: boolean()
  def can_sit?(unit_id) do
    can_stand?(unit_id) and
      not match?(%StatusEntry{}, StatusStorage.get_status(:player, unit_id, :sc_dancing)) and
      not channeling_gravitation?(:player, unit_id)
  end

  @doc """
  Returns whether a player may stand up: no body state (stone, freeze, stun,
  sleep) holds them. The petrification wait phase does not.
  """
  @spec can_stand?(integer()) :: boolean()
  def can_stand?(unit_id) do
    :player
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(&(not locking_body_state?(&1)))
  end

  defp locking_body_state?(%StatusEntry{type: type}) do
    case Registry.get_definition(type) do
      nil -> false
      definition -> definition[:opt1] not in [nil, :stonewait, :burning]
    end
  end

  @doc "Returns whether a unit may send area chat while status effects are active."
  @spec can_chat?(unit_type(), integer()) :: boolean()
  def can_chat?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.prevents_chat?/1)

  @doc "Returns whether active statuses block equipment changes."
  @spec equip_change_blocked?(unit_type(), integer()) :: boolean()
  def equip_change_blocked?(unit_type, unit_id),
    do: restricted?(unit_type, unit_id, &PropertyChecker.prevents_equip_change?/1)

  @doc """
  Returns whether a unit may cast a specific skill.

  A status' `:blocked_skills` always denies its listed skills. Otherwise, a
  `prevents_skills` status does not block a skill it lists in `:allow_skills`.
  This lets a feigning-death player recast NV_TRICKDEAD to stand back up even
  though SC_TRICKDEAD prevents skills.
  """
  @spec can_use_skill?(unit_type(), integer(), integer()) :: boolean()
  def can_use_skill?(unit_type, unit_id, skill_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(fn %StatusEntry{type: type} = entry ->
      skill_id not in PropertyChecker.blocked_skills(type) and
        skill_allowed?(entry, unit_type, unit_id, skill_id)
    end)
  end

  @doc "True when an active status prevents ally-targeted support skills."
  @spec support_blocked?(unit_type(), integer()) :: boolean()
  def support_blocked?(unit_type, unit_id),
    do:
      restricted?(
        unit_type,
        unit_id,
        &PropertyChecker.has_property?(&1, :prevents_support_skills)
      )

  @doc """
  Returns whether a unit may be targeted, i.e. carries no `untargetable` status.
  """
  @spec targetable?(unit_type(), integer()) :: boolean()
  def targetable?(unit_type, unit_id),
    do: not restricted?(unit_type, unit_id, &PropertyChecker.untargetable?/1)

  @doc """
  Returns whether a unit is charmed against the candidate target.
  """
  @spec charmed_against?(unit_type(), integer(), integer()) :: boolean()
  def charmed_against?(unit_type, unit_id, target_id) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_winkcharm) do
      %StatusEntry{source_id: ^target_id} -> true
      _entry -> false
    end
  end

  @doc """
  Returns whether a unit is concealed, i.e. carries a status with the
  `:conceals` property (Hiding or Cloaking).

  Deliberately separate from `targetable?/2`, which has callers outside mob
  AI; changing it would silently alter player targeting and skill targeting.
  """
  @spec concealed?(unit_type(), integer()) :: boolean()
  def concealed?(unit_type, unit_id),
    do: restricted?(unit_type, unit_id, &PropertyChecker.has_property?(&1, :conceals))

  defp blocks_player_movement?(%StatusEntry{type: :sc_hiding}, unit_id),
    do: not tunnel_drive?(unit_id)

  defp blocks_player_movement?(%StatusEntry{type: :sc_dancing} = entry, unit_id) do
    case root(entry) do
      :always -> true
      :ensemble -> not longing?(unit_id)
      :none -> false
    end
  end

  defp blocks_player_movement?(%StatusEntry{type: :sc_gravitation, state: state}, _unit_id),
    do: match?(%{self?: true}, state)

  defp blocks_player_movement?(%StatusEntry{type: type}, _unit_id), do: prevents_movement?(type)

  defp blocks_player_attack?(%StatusEntry{type: :sc_dancing} = entry, unit_id),
    do: root(entry) == :none or not longing?(unit_id)

  defp blocks_player_attack?(%StatusEntry{type: type}, _unit_id), do: prevents_attack?(type)

  defp root(%StatusEntry{state: state, val4: partner_id}),
    do:
      Map.get(state, :root) ||
        if(is_integer(partner_id) and partner_id > 0, do: :ensemble, else: :none)

  defp longing?(unit_id), do: StatusStorage.has_status?(:player, unit_id, :sc_longing)

  defp skill_allowed?(%StatusEntry{type: :sc_dancing} = entry, :player, unit_id, skill_id) do
    if root(entry) != :none and longing?(unit_id),
      do: skill_id != 305 and not Catalog.replayable?(skill_id),
      else: skill_id in PropertyChecker.allowed_skills(:sc_dancing)
  end

  defp skill_allowed?(%StatusEntry{type: type}, _unit_type, _unit_id, skill_id),
    do: not prevents_skills?(type) or skill_id in PropertyChecker.allowed_skills(type)

  defp tunnel_drive?(unit_id) do
    case UnitRegistry.get_unit(:player, unit_id) do
      {:ok, {PlayerState, player, _pid}} -> Passives.hidden_move_speed(player) > 0
      _ -> false
    end
  end

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

  defp check_magic_immunity(unit_type, unit_id) do
    target = {unit_type, unit_id}

    with %{skill: skill, caster: caster} <- Origin.current(),
         {:ok, %SkillDefinition{damage_kind: :magic, target_type: target_type}} <-
           Catalog.by_name(skill),
         true <- MagicDefense.immune?(target),
         false <- target_type == :self and caster == target do
      {:error, :magic_immune}
    else
      _ -> :ok
    end
  end

  defp check_boss_immunity(
         %{boss_flag: true},
         _unit_type,
         _unit_id,
         _status_params,
         %{bypass_boss_immunity: true}
       ),
       do: :ok

  defp check_boss_immunity(%{boss_flag: true}, unit_type, unit_id, status_params, _definition) do
    {_val1, _val2, _val3, _val4, _tick, _flag, caster_id, _duration, _state, _phase} =
      StatusEntry.extract_params(status_params)

    source_type = StatusEntry.resolve_source_type(unit_type, unit_id, caster_id, status_params)

    if source_type == unit_type and caster_id == unit_id do
      :ok
    else
      {:error, :boss_immune}
    end
  end

  defp check_boss_immunity(_entity_info, _unit_type, _unit_id, _status_params, _definition),
    do: :ok

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

  defp roll_resistance(
         _unit_type,
         _unit_id,
         _status_id,
         %{permanent: true},
         _entity_info,
         _duration_override,
         _params
       ),
       do: {:ok, nil}

  defp roll_resistance(
         unit_type,
         unit_id,
         status_id,
         definition,
         entity_info,
         duration_override,
         status_params
       ) do
    if Keyword.get(status_params, :bypass_resistance, false) or
         Keyword.get(status_params, :no_avoid, false) do
      {:ok, duration_override || definition.duration || 10_000}
    else
      roll_resistance_with_adjustment(
        unit_type,
        unit_id,
        definition,
        entity_info,
        status_id,
        duration_override,
        status_params
      )
    end
  end

  defp roll_resistance_with_adjustment(
         unit_type,
         unit_id,
         definition,
         entity_info,
         status_id,
         duration_override,
         status_params
       ) do
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
    success_rate = apply_ailment_resistance(success_rate, unit_type, unit_id, status_id)

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

  defp apply_ailment_resistance(success_rate, unit_type, unit_id, status_id) do
    if PropertyChecker.debuff?(status_id) do
      resistance =
        unit_type
        |> ModifierCalculator.get_all_modifiers(unit_id)
        |> Map.get(:ailment_resist_rate, 0)

      max(success_rate - resistance, 0)
    else
      success_rate
    end
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

      if StatusStorage.get_status(unit_type, unit_id, status_id) === stored_instance,
        do: :current,
        else: :superseded
    else
      :current
    end
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
      :superseded
    end
  end

  defp reconcile_replaced_status_ids([], unit_type, unit_id, status_id, stored_instance) do
    if StatusStorage.get_status(unit_type, unit_id, status_id) === stored_instance,
      do: :current,
      else: :superseded
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
        :superseded

      replaced_instance ->
        expire_status_if_current(unit_type, unit_id, replaced_status_id, replaced_instance)

        reconcile_replaced_status_ids(
          [replaced_status_id | rest],
          unit_type,
          unit_id,
          status_id,
          stored_instance
        )
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
      next_tick_at: if(tick > 0, do: now_ms + tick, else: nil),
      tick_count: 0,
      expires_at: nil
    }

    {duration, instance} = resolve_duration(definition, instance, duration, status_params)
    context = ContextBuilder.build_context(unit_type, unit_id, caster_id, instance)

    case definition.module.on_apply({unit_type, unit_id}, instance, context) do
      {:ok, new_instance} ->
        store_applied_status(
          unit_type,
          unit_id,
          status_id,
          duration,
          definition,
          instance,
          new_instance,
          status_params
        )

      :remove ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_duration(_definition, instance, nil, _status_params), do: {nil, instance}

  defp resolve_duration(definition, instance, duration, status_params) do
    if Keyword.get(status_params, :loaded, false),
      do: {duration, instance},
      else: definition.module.resolve_duration(instance, duration)
  end

  defp store_applied_status(
         unit_type,
         unit_id,
         status_id,
         duration,
         definition,
         instance,
         new_instance,
         status_params
       ) do
    case StatusStorage.apply_status_with_entry(unit_type, unit_id, status_id,
           val1: instance.val1,
           val2: instance.val2,
           val3: instance.val3,
           val4: instance.val4,
           tick: instance.tick,
           flag: instance.flag,
           duration: duration,
           caster_id: instance.source_id,
           source_type: instance.source_type,
           state: new_instance.state || %{},
           phase: new_instance.phase
         ) do
      {:stored, stored_instance, prior_instance} ->
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
    with :current <-
           reconcile_replaced_same_status(
             unit_type,
             unit_id,
             status_id,
             stored_instance,
             prior_instance,
             definition
           ),
         :current <-
           reconcile_replaced_statuses(unit_type, unit_id, status_id, stored_instance, definition) do
      finish_application(unit_type, unit_id, status_id, stored_instance, status_params)
    else
      :superseded -> :ok
    end
  end

  defp cleanup_unstored_application(unit_type, unit_id, definition, instance) do
    context =
      ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

    definition.module.on_expire({unit_type, unit_id}, instance, context)
    :ok
  end

  defp finish_application(unit_type, unit_id, status_id, stored_instance, status_params) do
    case ensure_living_target(unit_type, unit_id) do
      :ok ->
        if StatusStorage.get_status(unit_type, unit_id, status_id) === stored_instance do
          StatusDisplay.on_applied(unit_type, unit_id, status_id, stored_instance)
          notify_unit_status_applied(unit_type, unit_id, status_id)

          maybe_refresh_owner(unit_type, unit_id, true,
            owner_refresh: Keyword.get(status_params, :owner_refresh, :auto)
          )
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
      expire_status_entry(unit_type, unit_id, status_id, stored_instance)
    end

    :ok
  end

  defp discard_application(unit_type, unit_id, status_id, stored_instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, stored_instance) do
      expire_status_entry(unit_type, unit_id, status_id, stored_instance)
    end

    :ok
  end

  @doc """
  Expires a status only when `instance` is still the current stored generation.

  The compare-delete is atomic. On an actual removal, this runs the status's
  `on_expire` callback and removes its display when no newer same-type generation
  is active. Returns whether the captured entry was removed.
  """
  @spec expire_status_if_current(unit_type(), integer(), atom(), StatusEntry.t()) :: boolean()
  def expire_status_if_current(unit_type, unit_id, status_id, instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance) do
      expire_status_entry(unit_type, unit_id, status_id, instance)
      true
    else
      false
    end
  end

  @doc """
  Runs the timeout of a status that was just removed for running out its duration.

  Calls the definition's `on_timeout` callback with the expired `instance` and
  applies the `{status_id, params}` follow-ups it returns to the same holder.
  Call it only after the expiry actually removed `instance`.
  """
  @spec run_timeout(unit_type(), integer(), atom(), StatusEntry.t()) :: :ok
  def run_timeout(unit_type, unit_id, status_id, instance) do
    if MapSet.member?(Registry.statuses_implementing(:on_timeout), status_id) do
      %{module: module} = Registry.get_definition(status_id)
      context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

      {unit_type, unit_id}
      |> module.on_timeout(instance, context)
      |> Enum.each(fn {follow_up_id, params} ->
        apply_status(unit_type, unit_id, follow_up_id, params)
      end)
    else
      :ok
    end
  end

  defp expire_status_entry(unit_type, unit_id, status_id, instance) do
    %{module: module} = Registry.get_definition(status_id)
    context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

    module.on_expire({unit_type, unit_id}, instance, context)

    if is_nil(StatusStorage.get_status(unit_type, unit_id, status_id)) do
      StatusDisplay.on_removed(unit_type, unit_id, status_id, instance)
    end
  end

  defp expire_replaced_status_entry(unit_type, unit_id, status_id, instance) do
    %{module: module} = Registry.get_definition(status_id)
    context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

    module.on_expire({unit_type, unit_id}, instance, context)
  end

  defp notify_unit_status_applied(:mob, unit_id, status_id) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:casting, {:status_changed, status_id, :apply}})

      _ ->
        :ok
    end
  end

  defp notify_unit_status_applied(:homunculus, unit_id, status_id) do
    notify_homunculus_owner(unit_id, status_id, :applied)
  end

  defp notify_unit_status_applied(_unit_type, _unit_id, _status_id), do: :ok

  defp notify_unit_status_removed(:mob, unit_id, status_id) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:casting, {:status_changed, status_id, :removed}})

      _ ->
        :ok
    end
  end

  defp notify_unit_status_removed(:homunculus, unit_id, status_id) do
    notify_homunculus_owner(unit_id, status_id, :removed)
  end

  defp notify_unit_status_removed(_unit_type, _unit_id, _status_id), do: :ok

  defp notify_homunculus_owner(unit_id, status_id, event) do
    case UnitRegistry.get_unit(:homunculus, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:homunculus, {:status_changed, unit_id, status_id, event}})

      _ ->
        :ok
    end
  end

  defp resolve_tick(tick, _definition) when tick > 0, do: tick
  defp resolve_tick(_tick, %{tick_interval: interval}) when is_integer(interval), do: interval
  defp resolve_tick(tick, _definition), do: tick

  defp dispatch_damage(unit_type, unit_id, instance, damage_info),
    do: dispatch_hook(:on_damage, unit_type, unit_id, instance, damage_info)

  # Explicit precedence for the statuses that can intercept an incoming weapon
  # hit, so the winner is deterministic rather than defined by storage iteration
  # order. Definitive reactions resolve before the chance-based block: a caught
  # blade halts the exchange, then a qualifying melee counter, then a qualifying
  # poison-attack counter, and finally the probabilistic shield block - so a
  # guaranteed reaction is never pre-empted by a chance roll. Any interceptor not
  # listed here sorts last, preserving today's behaviour until it is placed.
  @weapon_hit_interception_order [
    :sc_bladestop_wait,
    :sc_auto_counter,
    :sc_poisonreact,
    :sc_autoguard
  ]

  defp find_weapon_hit_interception(unit_type, unit_id, implementing, attack_info) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&MapSet.member?(implementing, &1.type))
    |> Enum.sort_by(&weapon_hit_interception_priority(&1.type))
    |> Enum.find_value(:continue, fn instance ->
      case dispatch_before_weapon_hit(unit_type, unit_id, instance, attack_info) do
        :continue -> nil
        {:intercept, _result} = interception -> interception
      end
    end)
  end

  defp weapon_hit_interception_priority(status_id) do
    Enum.find_index(@weapon_hit_interception_order, &(&1 == status_id)) ||
      length(@weapon_hit_interception_order)
  end

  defp dispatch_before_weapon_hit(unit_type, unit_id, instance, attack_info) do
    case Registry.get_definition(instance.type) do
      nil ->
        :continue

      definition ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

        case definition.module.before_weapon_hit(
               {unit_type, unit_id},
               instance,
               attack_info,
               context
             ) do
          :continue ->
            :continue

          {:intercept, _result} = interception ->
            interception

          result ->
            raise "invalid before_weapon_hit result for #{instance.type}: #{inspect(result)}"
        end
    end
  end

  defp claim_normal_attack_modifier(unit_type, unit_id, instance, attack_info) do
    case Registry.get_definition(instance.type) do
      nil ->
        nil

      %{module: module} ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

        case module.before_normal_attack({unit_type, unit_id}, instance, attack_info, context) do
          :continue ->
            nil

          {:claim, modifier} ->
            claim_bounded_modifier(unit_type, unit_id, instance, modifier)

          result ->
            raise "invalid before_normal_attack result for #{instance.type}: #{inspect(result)}"
        end
    end
  end

  defp claim_bounded_modifier(unit_type, unit_id, instance, modifier) do
    if valid_normal_attack_modifier?(modifier) do
      if expire_status_if_current(unit_type, unit_id, instance.type, instance),
        do: modifier,
        else: nil
    else
      raise "invalid before_normal_attack result for #{instance.type}: #{inspect(modifier)}"
    end
  end

  defp valid_normal_attack_modifier?(%{damage_rate: rate} = modifier)
       when is_integer(rate) and rate >= 0 do
    allowed_keys? = Map.keys(modifier) |> Enum.all?(&(&1 in [:damage_rate, :poison]))
    allowed_keys? and valid_poison_rider?(Map.get(modifier, :poison))
  end

  defp valid_normal_attack_modifier?(_modifier), do: false

  defp valid_poison_rider?(nil), do: true

  defp valid_poison_rider?(%{chance: chance, level: level, duration: duration} = poison) do
    Map.keys(poison) |> Enum.sort() == [:chance, :duration, :level] and
      is_integer(chance) and chance in 1..100 and
      is_integer(level) and level > 0 and
      is_integer(duration) and duration > 0
  end

  defp valid_poison_rider?(_poison), do: false

  defp dispatch_after_damage_taken(unit_type, unit_id, instance, hit_info) do
    case Registry.get_definition(instance.type) do
      nil ->
        0

      definition ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

        case definition.module.after_damage_taken(
               {unit_type, unit_id},
               instance,
               hit_info,
               context
             ) do
          :ok ->
            0

          {:reflect, amount} when is_integer(amount) and amount > 0 ->
            amount

          {:reflect, _amount} ->
            0

          :remove ->
            expire_status_if_current(unit_type, unit_id, instance.type, instance)
            0

          result ->
            raise "invalid after_damage_taken result for #{instance.type}: #{inspect(result)}"
        end
    end
  end

  defp dispatch_dealt_damage(unit_type, unit_id, instance, hit_info),
    do: dispatch_hook(:on_dealt_damage, unit_type, unit_id, instance, hit_info)

  defp dispatch_committed_action(unit_type, unit_id, instance, action, unchanged) do
    case Registry.get_definition(instance.type) do
      nil ->
        unchanged

      %{module: module} ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)
        result = module.on_committed_action({unit_type, unit_id}, instance, action, context)
        apply_committed_action_result(result, unit_type, unit_id, instance, unchanged)
    end
  end

  defp apply_committed_action_result(
         {:ok, new_instance},
         unit_type,
         unit_id,
         instance,
         unchanged
       ) do
    updated = %{instance | state: new_instance.state, phase: new_instance.phase}

    if updated != instance and
         StatusStorage.replace_status_if_current(
           unit_type,
           unit_id,
           instance.type,
           instance,
           updated
         ),
       do: :changed,
       else: unchanged
  end

  defp apply_committed_action_result(:remove, unit_type, unit_id, instance, unchanged) do
    if expire_status_if_current(unit_type, unit_id, instance.type, instance),
      do: :changed,
      else: unchanged
  end

  defp apply_committed_action_result({:error, reason}, _unit_type, _unit_id, instance, unchanged) do
    Logger.warning("Status #{instance.type} on_committed_action failed: #{inspect(reason)}")
    unchanged
  end

  defp apply_committed_action_result(invalid, _unit_type, _unit_id, instance, _unchanged) do
    raise "invalid on_committed_action result for #{instance.type}: #{inspect(invalid)}"
  end

  defp dispatch_movement_intent(unit_type, unit_id, instance, position) do
    case Registry.get_definition(instance.type) do
      nil ->
        false

      definition ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

        case definition.module.on_movement_intent(
               {unit_type, unit_id},
               instance,
               position,
               context
             ) do
          {:ok, new_instance} ->
            store_movement_changes_if_current(
              unit_type,
              unit_id,
              instance,
              new_instance,
              definition.module,
              context
            )

          :remove ->
            removed? = expire_status_if_current(unit_type, unit_id, instance.type, instance)
            removed? and definition.module.modifiers(instance, context) != %{}

          {:error, reason} ->
            Logger.warning(
              "Status #{instance.type} on_movement_intent failed: #{inspect(reason)}"
            )

            false

          result ->
            raise "invalid on_movement_intent result for #{instance.type}: #{inspect(result)}"
        end
    end
  end

  defp store_movement_changes_if_current(
         unit_type,
         unit_id,
         instance,
         new_instance,
         module,
         context
       ) do
    updated = %{instance | state: new_instance.state || %{}, phase: new_instance.phase}

    if updated != instance and
         StatusStorage.replace_status_if_current(
           unit_type,
           unit_id,
           instance.type,
           instance,
           updated
         ) do
      module.modifiers(instance, context) != module.modifiers(updated, context)
    else
      false
    end
  end

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

  defp dispatch_absorb(_unit_type, _unit_id, nil, damage, _hit_info), do: damage

  defp dispatch_absorb(unit_type, unit_id, instance, damage, hit_info) do
    case Registry.get_definition(instance.type) do
      nil ->
        damage

      definition ->
        context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)
        hit_info = Map.put(hit_info, :damage, damage)

        definition.module.absorb_damage({unit_type, unit_id}, instance, hit_info, context)
        |> settle_absorb(unit_type, unit_id, instance, damage, {definition, context})
    end
  end

  defp settle_absorb({:ok, new_damage, new_instance}, unit_type, unit_id, instance, _, _) do
    store_instance_changes(unit_type, unit_id, instance.type, new_instance)
    new_damage
  end

  defp settle_absorb(:remove, unit_type, unit_id, instance, damage, _hooks) do
    remove_status(unit_type, unit_id, instance.type)
    damage
  end

  defp settle_absorb(
         {:remove, new_damage},
         unit_type,
         unit_id,
         %{type: :sc_aeterna},
         damage,
         hooks
       ) do
    case StatusStorage.take_status(unit_type, unit_id, :sc_aeterna) do
      nil ->
        damage

      claimed ->
        {definition, context} = hooks
        definition.module.on_expire({unit_type, unit_id}, claimed, context)
        StatusDisplay.on_removed(unit_type, unit_id, :sc_aeterna, claimed)
        new_damage
    end
  end

  defp settle_absorb({:remove, new_damage}, unit_type, unit_id, instance, _damage, _hooks) do
    remove_status(unit_type, unit_id, instance.type)
    new_damage
  end

  defp store_instance_changes(unit_type, unit_id, status_id, new_instance) do
    StatusStorage.update_status(unit_type, unit_id, status_id, fn entry ->
      %{entry | state: new_instance.state || %{}, phase: new_instance.phase}
    end)

    :ok
  end

  defp store_instance_changes_if_current(
         unit_type,
         unit_id,
         status_id,
         expected_generation,
         new_instance
       ) do
    StatusStorage.update_status(unit_type, unit_id, status_id, fn
      %StatusEntry{generation: ^expected_generation} = entry ->
        %{entry | state: new_instance.state || %{}, phase: new_instance.phase}

      current ->
        current
    end)
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

  defp ensure_eligible_target(:homunculus, %{require_weapon: [_ | _]}),
    do: {:error, :ineligible_target}

  defp ensure_eligible_target(unit_type, %{target_types: target_types}) do
    if unit_type in target_types, do: :ok, else: {:error, :ineligible_target}
  end

  defp ensure_living_target(unit_type, unit_id)
       when unit_type in [:player, :mob, :homunculus] do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, target_state, _pid}} ->
        if Unit.living?(target_state), do: :ok, else: {:error, :target_dead}

      {:error, :not_found} ->
        :ok
    end
  end

  defp ensure_living_target(_unit_type, _unit_id), do: :ok
end
