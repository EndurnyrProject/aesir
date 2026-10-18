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
  3. `on_damage/3` notifies eligible callbacks of the unit's delivered damage.
  4. `remove_status/3` runs `on_expire` and deletes the instance.
  """
  require Logger

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition, as: SkillDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRod
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
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

  @defense_stats [:str, :agi, :vit, :int, :dex, :luk]

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
  target is immune, protected or resisted it. Monster admission also rejects
  scripted player bonuses and unsupported mount/custom numeric statuses,
  including loaded applications; restoration never expands target eligibility.

  A status-immune target (a monster of the boss, guardian or battlefield class)
  rejects a status whose definition carries the `:boss` immunity (status.yml
  `BossResist`), whoever its source, with `{:error, :immune}`; every other
  status reaches it like any unit.

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

  A skill may pass `success_rate` (a percentage) and `resistance_roll` (given
  the final per-10000 rate) to combine its base application chance with the
  status defense (`Resistance.defend/2`) in one injectable final roll. The
  source of the defense is the caster (`caster_id`, typed by `source_type` or
  the unit registry), or the target itself without a caster; a caster no
  longer in the world leaves the status undefended and unrolled.
  `no_rate_def: true` (`SCSTART_NORATEDEF`) rolls the given chance without the
  target's rate defense; `no_tick_def: true` (`SCSTART_NOTICKDEF`) keeps the
  given duration. `bypass_resistance: true` skips the roll and all
  chance/stat/duration resistance while retaining immunity, prevention, and
  conflict gates.
  `no_avoid: true` additionally skips the immunity gates (race, element, boss and
  magic immunity): the application cannot be avoided, only prevented.

  `start_delay: ms` starts the status that many milliseconds later, as
  `status_change_start`'s delay: the immunity, Fail-list and defense checks run
  now and the application returns `:ok`; the rest (body-state replacement,
  end-on-start, overlap, storing) runs at the end of the delay if the target is
  still in the world and alive. Renewal shortens the duration by the delay.
  Bleeding ignores it and Stonewait's own wait is its delay.

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

  # Reference order (status_change_start): boss immunity (BossResist), then
  # EndReturn, then the Fail list, then the status defense (magic immunity first).
  defp apply_new_status(unit_type, unit_id, status_id, status_params, definition) do
    entity_info = get_entity_info(unit_type, unit_id)

    with :ok <- check_resisted(entity_info, status_params, definition) do
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
         :ok <- check_defended_magic(unit_type, unit_id, status_params),
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
      start(unit_type, unit_id, status_id, status_params, definition, duration)
    end
  end

  # A `start_delay` defers everything after the status defense by that many
  # milliseconds (status_change_start's `delay`): the application reports
  # success now, and the status starts at the end of the delay if its target
  # still lives. Renewal shortens the duration by the delay. Bleeding always
  # starts at once, and Stonewait's wait is already its own delay.
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
      create_and_store(unit_type, unit_id, status_id, status_params, definition, duration)
    end
  end

  defp check_resisted(entity_info, status_params, definition) do
    if Keyword.get(status_params, :no_avoid, false) do
      :ok
    else
      check_immunity(entity_info, immunities(definition, &(&1 == :boss)))
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

          remove_current_status_and_notify(unit_type, unit_id, status_id, instance)
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
  Notifies a unit's statuses of damage delivered to it, in its owning session.

  Active damage (`DamageShared.active_damage?/1`) first ends every held
  `:remove_on_damaged` status, even when it took no HP, except that a non-player
  keeps Wink of Charm unless the hit dealt damage (`:damage` above 0, or a coma
  hit's own `:hit_damage` above 0).
  When the unit held a body state (an `opt1` status), the first status ended is
  recorded for 10 ms (`StatusStorage.note_last_effect/4`), so the same attack
  cannot start a status whose Fail list names it. Active damage then runs the
  remaining `on_damage` callbacks; HP-dependent callbacks also see positive
  passive HP loss.

  `damage_info` is a map with at least `:damage` (the HP the hit took, 0 for
  none) and `:element`; the damage handlers also populate `:hp_after`,
  `:max_hp` and `:attacker`. An `on_damage` callback may request follow-up
  status applications; they are drained after every status has been notified.
  """
  @spec on_damage(unit_type(), integer(), map()) :: :ok
  def on_damage(unit_type, unit_id, damage_info) do
    if DamageShared.active_damage?(damage_info),
      do: end_damage_broken(unit_type, unit_id, damage_info)

    implementing = Registry.statuses_implementing(:on_damage)

    follow_ups =
      unit_type
      |> StatusStorage.get_unit_statuses(unit_id)
      |> Enum.filter(fn instance ->
        MapSet.member?(implementing, instance.type) and
          damage_callback_eligible?(instance.type, damage_info)
      end)
      |> Enum.flat_map(fn instance ->
        dispatch_damage(unit_type, unit_id, instance, damage_info)
      end)

    Enum.each(follow_ups, fn {status_id, params} ->
      apply_status(unit_type, unit_id, status_id, params)
    end)
  end

  defp damage_callback_eligible?(status, damage_info)
       when status in [:sc_berserk, :sc_autoberserk],
       do: Map.get(damage_info, :damage, 0) > 0 and Map.get(damage_info, :hp_after, 1) > 0

  defp damage_callback_eligible?(_status, damage_info),
    do: DamageShared.active_damage?(damage_info)

  # The order the first broken status is picked in. The reference walks an
  # unordered status table, so its order is unspecified; this is its status-type
  # order.
  @damage_broken_order [
    :sc_stone,
    :sc_freeze,
    :sc_sleep,
    :sc_hiding,
    :sc_cloaking,
    :sc_trickdead,
    :sc_winkcharm
  ]

  @typedoc """
  The damage-broken statuses a unit held when a hit was dealt: each status with
  its generation, in the order the first broken one is picked, and whether the
  unit held a body state (an `opt1` status) then.
  """
  @type damage_broken :: %{statuses: [{atom(), pos_integer()}], body_state?: boolean()}

  @doc """
  Captures the damage-broken statuses a unit holds as a hit is dealt to it.

  The attack path captures it before the hit's additional effects run and sends
  it with the hit as `:damage_broken`, so the owning session ends only what the
  unit held when the damage was dealt, never a status the same attack started
  afterwards. A notification without it ends what the unit holds when notified.
  """
  @spec damage_broken_snapshot(unit_type(), integer()) :: damage_broken()
  def damage_broken_snapshot(unit_type, unit_id) do
    statuses =
      :remove_on_damaged
      |> Registry.statuses_with_flag()
      |> Enum.flat_map(fn status_id ->
        case StatusStorage.get_status(unit_type, unit_id, status_id) do
          %StatusEntry{generation: generation} -> [{status_id, generation}]
          nil -> []
        end
      end)
      |> Enum.sort_by(fn {status_id, _generation} -> damage_broken_rank(status_id) end)

    %{statuses: statuses, body_state?: statuses != [] and holds_body_state?(unit_type, unit_id)}
  end

  defp end_damage_broken(unit_type, unit_id, damage_info) do
    %{statuses: held, body_state?: body_state?} =
      Map.get_lazy(damage_info, :damage_broken, fn ->
        damage_broken_snapshot(unit_type, unit_id)
      end)

    ended =
      Enum.filter(held, fn {status_id, generation} ->
        not keeps_without_hp?(status_id, unit_type, damage_info) and
          end_generation(unit_type, unit_id, status_id, generation)
      end)

    case ended do
      [{first, _generation} | _rest] when body_state? ->
        now = System.monotonic_time(:millisecond)
        StatusStorage.note_last_effect(unit_type, unit_id, first, now)

      _none ->
        :ok
    end

    maybe_refresh_owner(unit_type, unit_id, ended != [], [])
  end

  # Retries while the same generation is rewritten in place (a tick) between the
  # read and the compare-delete.
  defp end_generation(unit_type, unit_id, status_id, generation) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{generation: ^generation} = current ->
        expire_status_if_current(unit_type, unit_id, status_id, current) or
          end_generation(unit_type, unit_id, status_id, generation)

      _gone_or_newer ->
        false
    end
  end

  defp keeps_without_hp?(:sc_winkcharm, unit_type, damage_info) when unit_type != :player,
    do: battle_damage(damage_info) == 0

  defp keeps_without_hp?(_status, _unit_type, _damage_info), do: false

  # A battle coma counts its hit's own damage; a coma without one takes HP.
  defp battle_damage(%{coma?: true, hit_damage: damage}), do: damage
  defp battle_damage(%{coma?: true}), do: 1
  defp battle_damage(damage_info), do: Map.get(damage_info, :damage, 0)

  defp damage_broken_rank(status_id) do
    Enum.find_index(@damage_broken_order, &(&1 == status_id)) || length(@damage_broken_order)
  end

  defp holds_body_state?(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.any?(fn %StatusEntry{type: type} ->
      match?(%{opt1: opt1} when not is_nil(opt1), Registry.get_definition(type))
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
  above zero, the attacker's Add ATK Damage (weapon hits) or Add MATK Damage
  (magic hits) and the blockers (Kyrie Eleison, Safety Wall, Pneuma, Basilica),
  stopping at the first that leaves nothing. Storage order never matters.

  Status ticks and HP costs (`status_tick?: true`) are not attacks and skip both
  stages. Each callback sees the running `damage` in `hit_info`; returning
  `:remove` passes the hit through and expires the status, `{:remove, damage}`
  expires it after setting the running damage. Lex Aeterna is consumed through
  an exactly-once claim, so concurrent hits double at most once.
  """
  @spec absorb_damage(unit_type(), integer(), integer(), map()) :: integer()
  def absorb_damage(unit_type, unit_id, damage, hit_info),
    do: unit_type |> absorb_hit(unit_id, damage, hit_info) |> elem(0)

  @doc """
  Like `absorb_damage/4`, also classifying the hit: `:block` when Safety Wall,
  Pneuma or Basilica stopped it, `:hit` otherwise. A hit Kyrie Eleison or the
  common stages reduced to nothing still connected.
  """
  @spec absorb_hit(unit_type(), integer(), integer(), map()) :: {integer(), :hit | :block}
  def absorb_hit(_unit_type, _unit_id, 0, _hit_info), do: {0, :hit}

  def absorb_hit(unit_type, unit_id, damage, hit_info) do
    held = Map.new(StatusStorage.get_unit_statuses(unit_type, unit_id), &{&1.type, &1})
    run = &dispatch_absorb(unit_type, unit_id, Map.get(held, &1), &2, hit_info)

    attack_stages(damage, Map.get(hit_info, :status_tick?, false), run, hit_info)
  end

  @doc """
  Runs only the blocking statuses (Kyrie Eleison, Safety Wall, Pneuma,
  Basilica) over a single point of damage, for a weapon contact on an
  infinite-defense target. A Kyrie Eleison barrier loses that one point.
  Returns the damage left (`0` or `1`) and the `absorb_hit/4` classification.
  """
  @spec block_hit(unit_type(), integer(), map()) :: {0 | 1, :hit | :block}
  def block_hit(unit_type, unit_id, hit_info) do
    held = Map.new(StatusStorage.get_unit_statuses(unit_type, unit_id), &{&1.type, &1})
    run = &dispatch_absorb(unit_type, unit_id, Map.get(held, &1), &2, hit_info)
    Enum.reduce_while(@block_stage, {1, :hit}, fn id, acc -> block_step(id, acc, run) end)
  end

  @doc "Intercepts a same-source magic skill hit after ordinary reductions and blockers."
  @spec intercept_magic(unit_type(), integer(), map()) :: :miss | :continue
  def intercept_magic(unit_type, unit_id, hit_info) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_magicrod) do
      nil -> :continue
      instance -> MagicRod.intercept({unit_type, unit_id}, instance, hit_info)
    end
  end

  @doc "Every status id with a damage stage, in stage order."
  @spec absorb_stages() :: [atom()]
  def absorb_stages, do: @common_stage ++ @block_stage

  defp attack_stages(damage, true, _run, _hit_info), do: {damage, :hit}

  defp attack_stages(damage, false, run, hit_info) do
    case Enum.reduce(@common_stage, damage, run) do
      0 ->
        {0, :hit}

      remaining ->
        remaining
        |> attacker_damage(hit_info)
        |> then(
          &Enum.reduce_while(@block_stage, {&1, :hit}, fn id, acc -> block_step(id, acc, run) end)
        )
    end
  end

  # The attacker's own damage statuses, after the target's common stage and
  # before the blockers: Add ATK Damage on a weapon hit and Add MATK Damage on a
  # magic hit each add `val1` percent of the running damage.
  defp attacker_damage(damage, %{attacker: {unit_type, unit_id}} = hit_info) do
    case Map.get(hit_info, :dmg_type) do
      :physical -> add_attacker_percent(damage, unit_type, unit_id, :sc_add_atk_damage)
      :magic -> add_attacker_percent(damage, unit_type, unit_id, :sc_add_matk_damage)
      _other -> damage
    end
  end

  defp attacker_damage(damage, _hit_info), do: damage

  defp add_attacker_percent(damage, unit_type, unit_id, status_id) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{val1: val1} -> damage + div(damage * val1, 100)
      nil -> damage
    end
  end

  defp block_step(status_id, {damage, class}, run) do
    case run.(status_id, damage) do
      0 when status_id == :sc_kyrie -> {:halt, {0, :hit}}
      0 -> {:halt, {0, :block}}
      left -> {:cont, {left, class}}
    end
  end

  @doc """
  Removes a status effect, running its on_expire callback first.

  A status implementing `on_end_request/3` decides whether it ends; this holds
  for every removal below that goes through `remove_statuses/4` too. A holder
  already gone from the registry still ends it, its end logic seeing empty
  target stats.

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
  Restarts a held status as `replacement` only while `held` is still its current
  entry: stores it, arms its new deadline and refreshes its icon. Returns whether
  `replacement` was stored; a caller losing the race reads the status again.
  """
  @spec restart_status_if_current(
          unit_type(),
          integer(),
          atom(),
          StatusEntry.t(),
          StatusEntry.t()
        ) ::
          boolean()
  def restart_status_if_current(unit_type, unit_id, status_id, held, replacement) do
    if StatusStorage.replace_status_if_current(unit_type, unit_id, status_id, held, replacement) do
      StatusTickManager.arm(unit_type, unit_id, replacement)
      StatusDisplay.on_applied(unit_type, unit_id, status_id, replacement)
      notify_mob_status_write(unit_type, unit_id, status_id, :apply)
      true
    else
      false
    end
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
    if MapSet.member?(Registry.statuses_implementing(:on_end_request), status_id),
      do: request_end(unit_type, unit_id, status_id),
      else: end_status(unit_type, unit_id, status_id)
  end

  defp end_status(unit_type, unit_id, status_id) do
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

  # A status deciding how it ends (`on_end_request/3`): its outcome is stored
  # only over the entry it was asked about, asking again after a lost race.
  # Returns whether the status ended.
  defp request_end(unit_type, unit_id, status_id) do
    %{module: module} = Registry.get_definition(status_id)

    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      nil ->
        false

      instance ->
        context = end_context(unit_type, unit_id, instance)
        outcome = module.on_end_request({unit_type, unit_id}, instance, context)

        case store_end_outcome(outcome, unit_type, unit_id, status_id, instance) do
          :lost_race -> request_end(unit_type, unit_id, status_id)
          :kept -> false
          :ended -> finish_requested_end(module, unit_type, unit_id, instance, context, outcome)
        end
    end
  end

  defp store_end_outcome({:keep, kept, after_end}, unit_type, unit_id, status_id, instance) do
    if StatusStorage.replace_status_if_current(unit_type, unit_id, status_id, instance, kept) do
      after_end.()
      :kept
    else
      :lost_race
    end
  end

  defp store_end_outcome({:end, _after_end}, unit_type, unit_id, status_id, instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance),
      do: :ended,
      else: :lost_race
  end

  defp finish_requested_end(module, unit_type, unit_id, instance, context, {:end, after_end}) do
    module.on_expire({unit_type, unit_id}, instance, context)
    StatusDisplay.on_removed(unit_type, unit_id, instance.type, instance)
    notify_unit_status_removed(unit_type, unit_id, instance.type)
    after_end.()
    true
  end

  @doc """
  Removes statuses whose definitions set `remove_on_death: true` through
  the normal removal lifecycle, including infinite statuses with that flag.

  Permanent definitions default to surviving death unless explicitly opted in.
  The selected owner-refresh policy is applied once after the filtered batch.
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
    match?(%{remove_on_death: true}, Registry.get_definition(type))
  end

  @doc """
  Ends, through the normal removal path, the statuses a unit loses when it
  leaves its map: on every warp of a player, monster or Homunculus, the same
  map included.

  Those are the statuses flagged `remove_on_map_change`, Cloaking (every
  warp ends it, whatever the unit), the Battle Chant caster lock and an
  infinite Provoke (`val4` 1, the Auto Berserk one).
  """
  @spec remove_on_map_change(unit_type(), integer()) :: :ok
  def remove_on_map_change(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&remove_on_map_change?/1)
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, owner_refresh: :notify))
  end

  defp remove_on_map_change?(%StatusEntry{type: type})
       when type in [:sc_cloaking, :sc_gospel],
       do: true

  defp remove_on_map_change?(%StatusEntry{type: :sc_provoke, val4: val4}), do: val4 == 1

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

  @doc """
  Ends every status of a unit leaving the world (logout, despawn, a dead
  monster's removal, a homunculus put away) through its end logic, then drops
  whatever is left with the unit's status counters.

  Each status is taken out of storage before its `on_expire` runs. A status
  deciding how it ends (`on_end_request/3`) still runs its outcome, and is
  dropped even when it asks to stay. An infinite Endure never runs its end
  logic. An engine-only status has no end case of its own: it goes with the
  unit after the others ended. The holder may already be gone from the
  registry; its end logic then sees empty target stats. No owner refresh is
  published: the unit is leaving.
  """
  @spec end_removed_unit_statuses(unit_type(), integer()) :: :ok
  def end_removed_unit_statuses(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.each(&end_on_removal(unit_type, unit_id, &1.type))

    StatusStorage.clear_unit_statuses(unit_type, unit_id)
  end

  @doc """
  Ends, through their end logic and with no owner refresh, the unit's statuses
  a logout does not save: those whose definition sets `no_save`, and those
  setting `no_save_infinite` while infinite (`val4` set or no expiry). An
  infinite Endure refuses to end this way and stays. A logout runs it before
  saving the rest.
  """
  @spec end_unsaved_statuses(unit_type(), integer()) :: :ok
  def end_unsaved_statuses(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&unsaved?/1)
    |> Enum.reject(&infinite_endure?/1)
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, owner_refresh: :defer))
  end

  defp unsaved?(%StatusEntry{type: type} = entry) do
    case Registry.get_definition(type) do
      %{no_save: true} -> true
      %{no_save_infinite: true} -> entry.val4 > 0 or is_nil(entry.expires_at)
      _ -> false
    end
  end

  defp infinite_endure?(%StatusEntry{type: :sc_endure, val4: val4}), do: val4 != 0
  defp infinite_endure?(%StatusEntry{}), do: false

  defp end_on_removal(unit_type, unit_id, status_id) do
    case {Registry.get_definition(status_id),
          StatusStorage.get_status(unit_type, unit_id, status_id)} do
      {_definition, nil} ->
        :ok

      {nil, _instance} ->
        :ok

      {%{engine_only: true}, _instance} ->
        :ok

      {_definition, %StatusEntry{type: :sc_endure, val4: val4} = instance} when val4 != 0 ->
        remove_current_status_and_notify(unit_type, unit_id, status_id, instance)

      {%{module: module}, instance} ->
        context = end_context(unit_type, unit_id, instance)
        end_removed(module, unit_type, unit_id, instance, context)
    end

    :ok
  end

  defp end_removed(module, unit_type, unit_id, %StatusEntry{type: status_id} = instance, context) do
    after_end =
      if MapSet.member?(Registry.statuses_implementing(:on_end_request), status_id) do
        case module.on_end_request({unit_type, unit_id}, instance, context) do
          {:keep, _kept, after_end} -> {:dropped, after_end}
          {:end, after_end} -> {:ended, after_end}
        end
      else
        {:ended, fn -> :ok end}
      end

    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance) do
      finish_removal(after_end, module, unit_type, unit_id, instance, context)
    end
  end

  defp finish_removal({:dropped, after_end}, _module, _unit_type, _unit_id, _instance, _context),
    do: after_end.()

  defp finish_removal({:ended, after_end}, module, unit_type, unit_id, instance, context) do
    module.on_expire({unit_type, unit_id}, instance, context)
    StatusDisplay.on_removed(unit_type, unit_id, instance.type, instance)
    notify_unit_status_removed(unit_type, unit_id, instance.type)
    after_end.()
  end

  # Ending a status never needs its holder in the world: a holder already gone
  # (a removal's chained ends, an orphan) shows its end logic empty stats.
  defp end_context(unit_type, unit_id, instance) do
    target =
      if UnitRegistry.unit_exists?(unit_type, unit_id),
        do: ContextBuilder.get_unit_stats(unit_type, unit_id),
        else: %{}

    ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance, target)
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

  @gravitation_skill 484

  @doc """
  Whether a skill hit by `unit_type`/`unit_id` may be calculated at all.

  A pre-renewal player channelling their own Gravitation Field deals no other
  skill damage while the field lasts: only Gravitation Field itself and a skill
  running with the caster's autocast flag set (`autocast?`, an equipment proc)
  get through. Field occupants, monsters, renewal casters and ordinary attacks
  are never gated. The check belongs before any damage calculation; a refused
  hit is not a cast failure, so its costs stay spent.
  """
  @spec can_deal_skill_damage?(unit_type(), integer(), integer(), boolean()) :: boolean()
  def can_deal_skill_damage?(:player, unit_id, skill_id, autocast?) do
    autocast? or skill_id == @gravitation_skill or GameMode.mode() != :pre_renewal or
      not channeling_gravitation?(:player, unit_id)
  end

  def can_deal_skill_damage?(_unit_type, _unit_id, _skill_id, _autocast?), do: true

  @doc """
  `can_deal_skill_damage?/4` for an attacking combatant, read with its live
  autocast flag in the calling process: `:ok` to calculate the hit, `:suppressed`
  to skip it entirely. Every attack calculation entry calls it right after the
  delivery check.
  """
  @spec authorize_skill_damage(%{unit_type: unit_type(), unit_id: integer()}, integer()) ::
          :ok | :suppressed
  def authorize_skill_damage(%{unit_type: type, unit_id: id}, skill_id) do
    if can_deal_skill_damage?(type, id, skill_id, Origin.autocast?({type, id})),
      do: :ok,
      else: :suppressed
  end

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

  @lose_target_statuses [:sc_bladestop, :sc_cursedcircle_target, :sc__manhole]

  @doc """
  Returns whether a monster's statuses make it drop its target and pending
  attacked event: a body state other than the petrification wait or burning,
  or a status that loses the target (Blade Stop, Cursed Circle, Manhole).
  """
  @spec loses_target?(unit_type(), integer()) :: boolean()
  def loses_target?(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.any?(&(locking_body_state?(&1) or &1.type in @lose_target_statuses))
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
  though SC_TRICKDEAD prevents skills. A hidden player may use only a skill
  usable while hidden, and the Auto Counter stance allows no skill at all.

  `item?` marks a player's skill cast from an item: casting locks (Silence and
  the other statuses that forbid starting a cast) and skill blocks do not stop
  it, while a stun-like body state, playing dead, Blade Stop, a performance,
  the caster's own Battle Chant, Hiding and Auto Counter still do.
  """
  @spec can_use_skill?(unit_type(), integer(), integer(), boolean()) :: boolean()
  def can_use_skill?(unit_type, unit_id, skill_id, item? \\ false) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.all?(fn %StatusEntry{type: type} = entry ->
      (item? and not item_skill_lock?(entry)) or
        (skill_id not in PropertyChecker.blocked_skills(type) and
           skill_allowed?(entry, unit_type, unit_id, skill_id))
    end)
  end

  @item_skill_locks [
    :sc_trickdead,
    :sc_bladestop,
    :sc_dancing,
    :sc_gospel,
    :sc_hiding,
    :sc_auto_counter
  ]

  defp item_skill_lock?(%StatusEntry{type: type} = entry),
    do: type in @item_skill_locks or locking_body_state?(entry)

  @doc """
  Whether a performing unit's lock lets it use `skill_id`, as `can_use_skill?/3`
  judges it. A unit that is not performing is never locked.
  """
  @spec performance_allows_skill?(unit_type(), integer(), integer()) :: boolean()
  def performance_allows_skill?(unit_type, unit_id, skill_id) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_dancing) do
      %StatusEntry{} = entry -> skill_allowed?(entry, unit_type, unit_id, skill_id)
      _none -> true
    end
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
    allowed =
      if root(entry) != :none and longing?(unit_id),
        do: skill_id != 305 and not Catalog.replayable?(skill_id),
        else: skill_id in PropertyChecker.allowed_skills(:sc_dancing)

    allowed and not hermode_adaptation?(entry, skill_id)
  end

  defp skill_allowed?(%StatusEntry{type: :sc_auto_counter}, _unit_type, _unit_id, _skill_id),
    do: false

  defp skill_allowed?(%StatusEntry{type: :sc_winkcharm}, unit_type, _unit_id, _skill_id)
       when unit_type != :player,
       do: false

  defp skill_allowed?(%StatusEntry{type: :sc_hiding}, :player, _unit_id, skill_id),
    do: match?({:ok, %{allow_when_hidden: true}}, Catalog.by_id(skill_id))

  defp skill_allowed?(%StatusEntry{type: type}, _unit_type, _unit_id, skill_id),
    do: not prevents_skills?(type) or skill_id in PropertyChecker.allowed_skills(type)

  # Classic Adaptation cannot end a Wand of Hermode performance.
  defp hermode_adaptation?(%StatusEntry{val1: performance}, skill_id),
    do: GameMode.mode() == :pre_renewal and performance == 488 and skill_id == 304

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

  # The Fail list (`prevented_by` and `conflicts_with`) also fails on the status
  # damage last broke on the unit, while that record lasts.
  defp check_prevented(unit_type, unit_id, definition) do
    if fails_on?(unit_type, unit_id, definition.prevented_by) do
      {:error, :prevented}
    else
      :ok
    end
  end

  defp check_conflicts(unit_type, unit_id, definition) do
    if fails_on?(unit_type, unit_id, definition.conflicts_with) do
      {:error, :conflict}
    else
      :ok
    end
  end

  defp any_status_active?(unit_type, unit_id, status_ids) do
    Enum.any?(status_ids, &StatusStorage.has_status?(unit_type, unit_id, &1))
  end

  defp fails_on?(_unit_type, _unit_id, []), do: false

  defp fails_on?(unit_type, unit_id, status_ids) do
    any_status_active?(unit_type, unit_id, status_ids) or
      StatusStorage.last_effect(unit_type, unit_id, System.monotonic_time(:millisecond)) in status_ids
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
    tick = duration_override || definition.duration || 10_000

    if Keyword.get(status_params, :bypass_resistance, false) or
         Keyword.get(status_params, :no_avoid, false),
       do: {:ok, tick},
       else: defend(unit_type, unit_id, status_id, definition, entity_info, tick, status_params)
  end

  defp defend(unit_type, unit_id, status_id, definition, entity_info, tick, status_params) do
    status = if definition.bypass_resistance, do: nil, else: status_id
    rate = status_params |> Keyword.get(:success_rate, 100) |> Kernel.*(100) |> round()
    roll = Keyword.get(status_params, :resistance_roll, &Resistance.roll_rate/1)

    result =
      case defense_source(unit_type, unit_id, status_params) do
        :gone ->
          {:ok, tick}

        {:ok, {source_type, source_id, source_info}} ->
          if Resistance.defended?(status) do
            %{
              status: status,
              rate: rate,
              tick: tick,
              target: defense_view(unit_type, unit_id, entity_info),
              source: defense_view(source_type, source_id, source_info),
              scresist: held_val(unit_type, unit_id, :sc_scresist, :val1),
              siegfried: held_val(unit_type, unit_id, :sc_siegfried, :val2),
              res_eff:
                entity_info |> Map.get(:equip_modifiers, %{}) |> Map.get({:res_eff, status}, 0),
              roll: roll,
              no_rate_def: Keyword.get(status_params, :no_rate_def, false),
              no_tick_def: Keyword.get(status_params, :no_tick_def, false)
            }
            |> Resistance.defend(GameMode.mode())
          else
            Resistance.roll_chance(rate, tick, roll)
          end
      end

    case result do
      {:ok, duration} -> {:ok, duration}
      :resisted -> {:error, :resisted}
    end
  end

  # The source of a status defense: the caster, or the target without one. A
  # caster that has left the world is `:gone` and defends nothing.
  defp defense_source(unit_type, unit_id, status_params) do
    case Keyword.get(status_params, :caster_id) do
      nil ->
        {:ok, {unit_type, unit_id, get_entity_info(unit_type, unit_id)}}

      caster_id ->
        with {:ok, source_type} <- source_type(caster_id, status_params),
             {:ok, info} <- UnitRegistry.get_unit_info(source_type, caster_id) do
          {:ok, {source_type, caster_id, info}}
        else
          _missing -> :gone
        end
    end
  end

  defp source_type(caster_id, status_params) do
    case Keyword.get(status_params, :source_type) do
      nil -> UnitRegistry.unit_type_for(caster_id)
      source_type -> {:ok, source_type}
    end
  end

  defp held_val(unit_type, unit_id, status_id, field) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{} = entry -> Map.get(entry, field)
      nil -> nil
    end
  end

  # The stats a defense recipe reads: effective primary stats, hard MDEF and
  # base level. A monster's stats are read from its combatant so its statuses
  # count; a player's entity info already carries its effective stats.
  defp defense_view(unit_type, unit_id, entity_info) when unit_type in [:mob, :homunculus] do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {module, state, _pid}} -> combatant_view(module.to_combatant(state))
      {:error, :not_found} -> info_view(entity_info)
    end
  end

  defp defense_view(_unit_type, _unit_id, entity_info), do: info_view(entity_info)

  defp combatant_view(combatant) do
    %{
      player?: false,
      level: combatant.progression.base_level,
      mdef: Map.get(combatant.combat_stats, :mdef) || 0
    }
    |> Map.merge(Map.new(@defense_stats, &{&1, Map.get(combatant.base_stats, &1) || 0}))
  end

  defp info_view(entity_info) do
    stats = Map.get(entity_info, :stats) || %{}
    primary = Map.get(stats, :total_stats) || stats

    %{
      player?: Map.get(entity_info, :entity_type) == :player,
      level: Map.get(stats, :base_level) || Map.get(stats, :level) || 0,
      mdef: Map.get(stats, :mdef) || 0
    }
    |> Map.merge(Map.new(@defense_stats, &{&1, Map.get(primary, &1) || 0}))
  end

  # Magic immunity is the first step of the status defense, so an unavoidable
  # application and a caster no longer in the world skip it.
  defp check_defended_magic(unit_type, unit_id, status_params) do
    cond do
      Keyword.get(status_params, :no_avoid, false) -> :ok
      defense_source(unit_type, unit_id, status_params) == :gone -> :ok
      true -> check_magic_immunity(unit_type, unit_id)
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
      notify_mob_status_write(unit_type, unit_id, status_id, :removed)

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

    # The statuses this application ends before meeting the held instance: its
    # end-on-start list and, for a body state, every held body state.
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
        end_ended_on_start(unit_type, unit_id, status_id, definition)
        overlap_result(refused)
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
    remove_statuses(unit_type, unit_id, List.delete(definition.end_on_start, status_id))
  end

  # Inside the store's compare-and-swap the application meets what is current
  # again when it is no longer `held`: an instance stored, or the held one removed,
  # in between. `incoming` is the application before `overlap/3` adjusted it.
  defp store_decision(definition, target, held, incoming) do
    if incoming.type in definition.end_on_start do
      fn _current -> :store end
    else
      fn
        current when current === held -> :store
        current -> stored_decision(overlap(definition, target, current, incoming))
      end
    end
  end

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
           ],
           store_decision(definition, {unit_type, unit_id}, held, incoming)
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
      notify_mob_status_write(unit_type, unit_id, status_id, :removed)
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

  defp notify_unit_status_applied(:mob, unit_id, status_id),
    do: notify_mob_status_write(:mob, unit_id, status_id, :apply)

  defp notify_unit_status_applied(:homunculus, unit_id, status_id) do
    notify_homunculus_owner(unit_id, status_id, :applied)
  end

  defp notify_unit_status_applied(_unit_type, _unit_id, _status_id), do: :ok

  defp notify_unit_status_removed(:mob, unit_id, status_id),
    do: notify_mob_status_write(:mob, unit_id, status_id, :removed)

  defp notify_unit_status_removed(:homunculus, unit_id, status_id) do
    notify_homunculus_owner(unit_id, status_id, :removed)
  end

  defp notify_unit_status_removed(_unit_type, _unit_id, _status_id), do: :ok

  defp remove_current_status_and_notify(unit_type, unit_id, status_id, instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance),
      do: notify_mob_status_write(unit_type, unit_id, status_id, :removed)
  end

  defp notify_mob_status_write(:mob, unit_id, status_id, event) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:casting, {:status_changed, status_id, event}})

      _ ->
        :ok
    end
  end

  defp notify_mob_status_write(_unit_type, _unit_id, _status_id, _event), do: :ok

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
         ) do
      if instance.type == :sc_magicpower,
        do: notify_mob_status_write(unit_type, unit_id, instance.type, :armed)

      :changed
    else
      unchanged
    end
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
      notify_mob_status_write(unit_type, unit_id, instance.type, :apply)
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
        notify_mob_status_write(unit_type, unit_id, :sc_aeterna, :removed)
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
      fun.(definition.module, instance, end_context(unit_type, unit_id, instance))
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

  defp ensure_eligible_target(:mob, %{id: status_id, target_types: target_types}) do
    if :mob in target_types and CalcFlags.monster_eligible?(status_id),
      do: :ok,
      else: {:error, :ineligible_target}
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
