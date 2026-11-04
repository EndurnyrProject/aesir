defmodule Aesir.ZoneServer.Mmo.StatusEffect.CombatHooks do
  @moduledoc """
  Dispatches combat and movement events to the statuses a unit holds.

  The victim side: `on_damage/3` (damage delivered, in the owning session),
  `before_weapon_hit/3` (swing reactions), `absorb_hit/4`, `block_hit/3` and
  `final_weapon_hit/4` (the damage stages, in the fixed reference order),
  `intercept_magic/3` and `after_damage_taken/3`. The attacker side:
  `before_normal_attack/3`, `attack_replacement/2` and `on_dealt_damage/3`.
  Player actions and movement: `on_committed_action/3`,
  `on_movement_intent/3` and `on_movement_contact/3`.

  Each callback is dispatched only to the statuses the registry indexes for it,
  so a unit holding none costs one registry read.
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.StatusEffect.Applier
  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicRod
  alias Aesir.ZoneServer.Mmo.StatusEffect.Notifications
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Removal
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit

  @type unit_type :: Unit.unit_type()

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
  @block_stage [
    :sc_kyrie,
    :sc_safetywall,
    :sc_pneuma,
    :sc_basilica,
    :sc_basilica_caster,
    :sc_autoguard,
    :sc_parrying
  ]
  # Blockers whose stop is not a block: the hit reached the holder for nothing
  # (Kyrie Eleison absorbing it, a Guard or Parrying roll), so its additional
  # and counter stages are skipped like a miss rather than run as a block.
  # Only Guard classifies the stop as a miss itself (`:miss`); the others leave
  # the hit unclassified (`:hit`), which matters when a swing's other hand was
  # classified.
  @stop_as_miss [:sc_kyrie, :sc_autoguard, :sc_parrying]
  @classified_miss [:sc_autoguard]
  # After the siege map rate, before delivery (see final_weapon_hit/4).
  @final_weapon_stage [:sc_rejectsword]

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
      Applier.apply_status(unit_type, unit_id, status_id, params)
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
    :sc_chasewalk,
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

    {ended, events} =
      Enum.reduce(held, {[], []}, fn {status_id, generation} = entry, {ended, events} ->
        removed =
          if keeps_without_hp?(status_id, unit_type, damage_info),
            do: [],
            else: Removal.end_generation_events(unit_type, unit_id, status_id, generation)

        if removed == [],
          do: {ended, events},
          else: {ended ++ [entry], events ++ removed}
      end)

    case ended do
      [{first, _generation} | _rest] when body_state? ->
        now = System.monotonic_time(:millisecond)
        StatusStorage.note_last_effect(unit_type, unit_id, first, now)

      _none ->
        :ok
    end

    Notifications.maybe_refresh_owner(unit_type, unit_id, events, [])
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
  Dispatches the target's swing reactions (Auto Counter, Poison React, Blade
  Stop) before an ordinary weapon swing selects a replacement or rolls its hit.

  Each capable status may atomically consume a single-use entry of the target
  and return `{:intercept, result}`; the first interception wins and ends the
  swing. A target holding no such status stays on a constant-time no-op path.
  Shield blocks (Guard, Parrying) are not reactions to the swing: they roll in
  the damage stage (`absorb_hit/4`), after the hit roll.
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

  # Explicit precedence for the statuses that react to an incoming weapon
  # swing, in the order the reference checks them: a qualifying melee counter,
  # then a qualifying poison-attack counter, then a caught blade. Any
  # interceptor not listed here sorts last.
  @weapon_hit_interception_order [
    :sc_auto_counter,
    :sc_poisonreact,
    :sc_bladestop_wait
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
      if Removal.expire_status_if_current(unit_type, unit_id, instance.type, instance),
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
        Applier.apply_status(unit_type, unit_id, status_id, params)
      end)

      combat_follow_ups
    end
  end

  defp combat_follow_up?({:auto_cast, _, _, _}), do: true
  defp combat_follow_up?({:local_heal, _, _, _}), do: true
  defp combat_follow_up?(_follow_up), do: false

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
            Removal.expire_status_if_current(unit_type, unit_id, instance.type, instance)
            0

          result ->
            raise "invalid after_damage_taken result for #{instance.type}: #{inspect(result)}"
        end
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
        do: Notifications.notify_mob_status_write(unit_type, unit_id, instance.type, :armed)

      :changed
    else
      unchanged
    end
  end

  defp apply_committed_action_result(:remove, unit_type, unit_id, instance, unchanged) do
    if Removal.expire_status_if_current(unit_type, unit_id, instance.type, instance),
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
            removed? =
              Removal.expire_status_if_current(unit_type, unit_id, instance.type, instance)

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
      Notifications.notify_mob_status_write(unit_type, unit_id, instance.type, :apply)
      module.modifiers(instance, context) != module.modifiers(updated, context)
    else
      false
    end
  end

  @doc "Notifies active statuses that their holder made movement contact with a unit."
  @spec on_movement_contact(unit_type(), integer(), {unit_type(), integer()}) :: :ok
  def on_movement_contact(unit_type, unit_id, contact) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.each(&dispatch_contact(unit_type, unit_id, &1, contact))
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
            Removal.remove_status(unit_type, unit_id, instance.type)

          {:error, reason} ->
            Logger.warning("Status #{instance.type} on_contact failed: #{inspect(reason)}")
        end
    end
  end

  @doc """
  Runs the target's damage statuses over one prepared logical hit, in the fixed
  reference order, before HP is reduced. Returns the final integer damage; a
  hit of zero damage stays zero and touches no status.

  The stages are, in order: the common damage arithmetic (Lex Aeterna, Raid,
  Assumptio, Defending Aura, Blinding Mist, Energy Coat, Mental Strength), each
  step running even when an earlier one left nothing; then, only for damage left
  above zero, the attacker's Add ATK Damage (weapon hits) or Add MATK Damage
  (magic hits) and the blockers (Kyrie Eleison, Safety Wall, Pneuma, Basilica,
  Guard, Parrying), stopping at the first that leaves nothing. Storage order
  never matters.

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
  Pneuma or Basilica stopped it, `:miss` when Guard did, `:hit` otherwise. A
  hit Kyrie Eleison, Parrying or the common stages reduced to nothing is left
  unclassified, so it is a miss only by its damage.
  """
  @spec absorb_hit(unit_type(), integer(), integer(), map()) ::
          {integer(), :hit | :block | :miss}
  def absorb_hit(_unit_type, _unit_id, 0, _hit_info), do: {0, :hit}

  def absorb_hit(unit_type, unit_id, damage, hit_info) do
    held = Map.new(StatusStorage.get_unit_statuses(unit_type, unit_id), &{&1.type, &1})
    run = &dispatch_absorb(unit_type, unit_id, Map.get(held, &1), &2, hit_info)

    attack_stages(damage, Map.get(hit_info, :status_tick?, false), run, hit_info)
  end

  @doc """
  Runs only the blocking statuses (Kyrie Eleison, Safety Wall, Pneuma,
  Basilica, Guard, Parrying) over a single point of damage, for a weapon
  contact on an infinite-defense target. A Kyrie Eleison barrier loses that
  one point. Returns the damage left (`0` or `1`) and the `absorb_hit/4`
  classification.
  """
  @spec block_hit(unit_type(), integer(), map()) :: {0 | 1, :hit | :block | :miss}
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

  @doc """
  Runs the holder's final weapon stage (Counter Instinct) over one weapon hit's
  positive damage, after its damage statuses and the siege map rate. Returns the
  damage left and the damage owed back to the attacker.
  """
  @spec final_weapon_hit(unit_type(), integer(), non_neg_integer(), map()) ::
          {non_neg_integer(), non_neg_integer()}
  def final_weapon_hit(unit_type, unit_id, damage, hit_info) do
    Enum.reduce(@final_weapon_stage, {damage, 0}, fn status_id, acc ->
      final_weapon_step(unit_type, unit_id, status_id, acc, hit_info)
    end)
  end

  @doc "Every status id in the final weapon stage, in stage order."
  @spec final_weapon_stages() :: [atom()]
  def final_weapon_stages, do: @final_weapon_stage

  defp final_weapon_step(_unit_type, _unit_id, _status_id, {0, _owed} = acc, _hit_info), do: acc

  defp final_weapon_step(unit_type, unit_id, status_id, {damage, owed} = acc, hit_info) do
    with %{} = instance <- StatusStorage.get_status(unit_type, unit_id, status_id),
         %{module: module} <- Registry.get_definition(status_id),
         {:counter, damage, counter} <-
           module.final_weapon_hit({unit_type, unit_id}, instance, damage, hit_info) do
      {damage, owed + counter}
    else
      _continue -> acc
    end
  end

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
      0 when status_id in @classified_miss -> {:halt, {0, :miss}}
      0 when status_id in @stop_as_miss -> {:halt, {0, :hit}}
      0 -> {:halt, {0, :block}}
      left -> {:cont, {left, class}}
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
    Removal.remove_status(unit_type, unit_id, instance.type)
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

        Removal.end_on_end(
          unit_type,
          unit_id,
          :sc_aeterna,
          &Removal.remove_status_without_refresh/3
        )

        StatusDisplay.on_removed(unit_type, unit_id, :sc_aeterna, claimed)
        Notifications.notify_mob_status_write(unit_type, unit_id, :sc_aeterna, :removed)
        new_damage
    end
  end

  defp settle_absorb({:remove, new_damage}, unit_type, unit_id, instance, _damage, _hooks) do
    Removal.remove_status(unit_type, unit_id, instance.type)
    new_damage
  end

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
            Removal.remove_status(unit_type, unit_id, instance.type)
            []

          {:error, reason} ->
            Logger.warning("Status #{instance.type} #{hook} failed: #{inspect(reason)}")
            []
        end
    end
  end

  defp store_instance_changes(unit_type, unit_id, status_id, new_instance) do
    StatusStorage.update_status(unit_type, unit_id, status_id, fn entry ->
      %{entry | state: new_instance.state || %{}, phase: new_instance.phase}
    end)

    :ok
  end
end
