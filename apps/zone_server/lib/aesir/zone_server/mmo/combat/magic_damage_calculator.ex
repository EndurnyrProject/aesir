defmodule Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator do
  @moduledoc """
  Single-hit renewal magic damage calculation.

  Mirrors the physical `DamageCalculator` interface and result shape so
  downstream packet/HP-apply code is shared: it returns the same
  `%{damage: non_neg_integer(), is_critical: false}`. Magic always hits and
  never crits, so there is no hit/flee or critical step.

  ## Pipeline

  1. Base MATK: a roll over the attacker's `matk_min`/`matk_max` band. rAthena
     rolls this per target inside `battle_calc_magic_attack` (battle.cpp:5969),
     so each call rolls independently.
  2. Target-aware Renewal magic cardfix, each family applied and truncated
     consecutively (`magic_addsize`, then `magic_addrace`, then `magic_addele`
     vs the defender's element, then the equipment-only `magic_atk_ele` vs the
     spell element and `skill_atk` vs the skill id). Each family sums its status
     and equipment sources into one multiplicative stage; the race term also
     folds in Dragonology's precomputed `+2*lv%` vs Dragon race and `-4*lv%`
     resist from a Dragon-race attacker (`status.cpp:4682-4700`) — all run
     inside rAthena's early `battle_calc_cardfix`, ahead of MDEF.
  3. S.MAtk: attacker's `smatk` combat stat added as a percentage of the
     rolled base MATK, before the skill ratio (`battle.cpp:6016`).
  4. Skill ratio + flat MATK bonus.
  5. Attacker status `matk_rate` (percent delta on magic damage).
  6. Element resistance (skill element vs defender element/level).
  7. Generic status `damage_multiplier`.
  8. MRes: defender's `mres` combat stat reduces damage on the same
     soft-capped curve as physical Res, before MDEF (`battle.cpp:6067`).
  8b. Defender `sub*` equipment families (race+class, element vs spell element,
     size) as multiplicative damage-taken reductions.
  9. Renewal MDEF reduction (`battle.cpp:6105`), with the defender's status
     `mdef_rate` scaling hard MDEF first and the attacker's equipment
     ignore-mdef bypassing a percent of it:
     `dmg = matk * (1000 + hardMDEF) / (1000 + 10*hardMDEF) - softMDEF`.
  10. Defender status `magic_damage_reduction` (percent of final magic damage
     the target shrugs off, clamped 0..100).
  11. Min-1 clamp.

  Hard MDEF folds the defender's status/equipment MDEF (players) or the mob's
  flat MDEF; the consumable `mdef_rate`/`magic_damage_reduction` status keys
  are applied on top as noted above.

  S.MAtk applies only to this pipeline's `matk`/`matk_min`/`matk_max` roll.
  Healing (`AlHeal`) computes its value from the separate `heal_matk_min`/
  `heal_matk_max` fields via its own formula, and its undead/demon
  heal-as-damage branch goes through `Combat.execute_magic_damage/4` (element
  + min-1 clamp on the precomputed heal value) rather than this module, so
  `smatk` never reaches it.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  # All-zero equipment rates used when a combatant is a bare test map rather than
  # a `%Combatant{}` (only real combatants carry a folded `equip_modifiers` map).
  @zero_equip_rates %{
    attack: %{race: 0, element_target: 0, size: 0, atk_ele: 0, skill: 0},
    taken: %{race_class: 0, element: 0, size: 0},
    ignore_mdef: 0
  }

  @typedoc """
  Result of a magic damage calculation. Magic never crits.
  """
  @type magic_damage_result :: %{
          damage: non_neg_integer(),
          is_critical: false
        }

  @doc """
  Calculates single-hit renewal magic damage from `attacker` to `defender`.

  ## Options

    - `:skill_ratio` - percent of base MATK the skill deals (default `100`).
    - `:bonus_matk` - flat MATK added after the skill-ratio step (default `0`).
    - `:element` - the skill's attack element used for the defender's element
      resistance step (default `:neutral`).
    - `:fixed_damage` - when set, short-circuits the entire pipeline and returns
      that flat value (default `nil`).
    - `:ignore_mdef` - bypasses the defender's hard and soft MDEF while
      preserving the normal element, status, cardfix, MRes, and damage-taken
      stages (default `false`).

  ## Returns

    - `{:ok, %{damage: non_neg_integer(), is_critical: false}}` on success.
    - `{:error, reason}` on failure.
  """
  @spec calculate_magic_damage(Combatant.t() | map(), Combatant.t() | map(), keyword()) ::
          {:ok, magic_damage_result()} | {:error, atom()}
  def calculate_magic_damage(attacker, defender, opts \\ []) do
    case Keyword.get(opts, :fixed_damage) do
      nil -> calculate_pipeline_damage(attacker, defender, opts)
      fixed_damage -> {:ok, %{damage: fixed_damage, is_critical: false}}
    end
  end

  @doc """
  Rolls a single MATK from a combatant's `combat_stats` variance band.

  Falls back to the deterministic `:matk` when the band keys are absent (legacy
  combatants), so a missing band behaves exactly like a fixed MATK.
  """
  @spec roll_matk(map()) :: non_neg_integer()
  def roll_matk(combat_stats) do
    DamageShared.roll(
      Map.get(combat_stats, :matk_min, combat_stats.matk),
      Map.get(combat_stats, :matk_max, combat_stats.matk)
    )
  end

  @spec calculate_pipeline_damage(map(), map(), keyword()) :: {:ok, magic_damage_result()}
  defp calculate_pipeline_damage(attacker, defender, opts) do
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    bonus_matk = Keyword.get(opts, :bonus_matk, 0)
    element = Keyword.get(opts, :element, :neutral)
    skill_id = Keyword.get(opts, :skill_id)
    equip = equipment_rates(attacker, defender, skill_id, element)

    # rAthena rolls MATK inside battle_calc_magic_attack, which runs per target
    # (battle.cpp:5969), so each call rolls its own MATK independently.
    base_matk = roll_matk(attacker.combat_stats)
    modifiers = combatant_modifiers(attacker)
    base_matk = apply_target_modifiers(base_matk, modifiers, attacker, defender, equip.attack)
    smatk = Map.get(attacker.combat_stats, :smatk, 0)
    base_matk = base_matk + div(base_matk * smatk, 100)
    # :matk_rate is an additive percent delta on magic damage (SC_INCMATKRATE,
    # SC_COMBAT_PILL), applied to the skill-scaled MATK.
    matk_rate = Map.get(modifiers, :matk_rate, 0)
    skilled = div((div(base_matk * skill_ratio, 100) + bonus_matk) * (100 + matk_rate), 100)
    defender_modifiers = combatant_modifiers(defender)
    mres = Map.get(defender.combat_stats, :mres, 0)

    ignore_mdef? = Keyword.get(opts, :ignore_mdef, false)

    damage =
      skilled
      |> DamageShared.apply_element(element, defender, modifiers)
      |> DamageShared.apply_damage_multiplier(modifiers)
      |> DamageShared.res_reduction(mres)
      |> apply_damage_taken_reductions(equip.taken)
      |> apply_mdef_formula(
        defender,
        defender_modifiers,
        if(ignore_mdef?, do: 100, else: equip.ignore_mdef),
        ignore_mdef?
      )
      |> apply_magic_damage_reduction(defender_modifiers)
      |> DamageShared.clamp_min_one()

    {:ok, %{damage: damage, is_critical: false}}
  end

  # Renewal cardfix applies target-size then target-race magic bonuses as
  # separate integer stages before S.MAtk and the skill ratio (rAthena
  # battle.cpp:807-828, 6008-6020). Tuple keys keep the modifier values numeric,
  # so the existing ModifierCalculator can sum them. Dragonology's percentage
  # MATK bonus (attacker, `status.cpp:4682-4700`) and its percentage
  # damage-taken resistance (defender, same block) both fold into this same
  # race cardfix term, net of each other, since rAthena runs both inside the
  # same early `battle_calc_cardfix` — well before the MDEF formula's
  # subtractive `- soft` term, which does not commute with a later percentage
  # multiply.
  # Equipment `magic_add*` sums fold into the same-named status cardfix step so
  # each family stays one multiplicative stage summing both sources exactly once.
  # `magic_atk_ele` (keyed on the spell element) and `skill_atk` (keyed on the
  # skill id) apply as their own equipment-only cardfix stages, identity at 0.
  @spec apply_target_modifiers(integer(), map(), map(), map(), map()) :: integer()
  defp apply_target_modifiers(damage, modifiers, attacker, defender, equip_attack) do
    size_bonus =
      Map.get(modifiers, {:magic_addsize, Map.get(defender, :size)}, 0) +
        Map.get(modifiers, {:magic_addsize, :all}, 0) +
        equip_attack.size

    race_bonus =
      Map.get(modifiers, {:magic_addrace, Map.get(defender, :race)}, 0) +
        Map.get(modifiers, {:magic_addrace, :all}, 0) +
        RaceModifiers.dragonology_matk_rate(attacker, Map.get(defender, :race)) -
        RaceModifiers.dragonology_resist_rate(defender, Map.get(attacker, :race)) +
        equip_attack.race

    element_bonus =
      Map.get(modifiers, {:magic_addele, defender_element(defender)}, 0) +
        Map.get(modifiers, {:magic_addele, :all}, 0) +
        equip_attack.element_target

    damage
    |> apply_cardfix(size_bonus)
    |> apply_cardfix(race_bonus)
    |> apply_cardfix(element_bonus)
    |> apply_cardfix(equip_attack.atk_ele)
    |> apply_cardfix(equip_attack.skill)
  end

  defp defender_element(defender) do
    case Map.get(defender, :element, :neutral) do
      {element, _level} -> element
      element -> element
    end
  end

  # Mirrors APPLY_CARDFIX_RE rather than multiplying by the final percentage.
  # The removed/added amount is truncated toward zero first; this matters for
  # reductions (101 at -5% removes 5 and yields 96, not floor(95.95) = 95).
  defp apply_cardfix(damage, bonus) do
    fix = max(0, 100 + bonus)
    damage - div(damage * (100 - fix), 100)
  end

  # Defender `sub*` equipment families reduce incoming magic damage as their own
  # multiplicative steps (race+class share one sum), keyed on the attacker's
  # traits and the spell element. Zero families are pass-through.
  @spec apply_damage_taken_reductions(number(), map()) :: number()
  defp apply_damage_taken_reductions(damage, taken) do
    damage
    |> reduce_by(taken.race_class)
    |> reduce_by(taken.element)
    |> reduce_by(taken.size)
  end

  defp reduce_by(damage, 0), do: damage
  defp reduce_by(damage, rate), do: damage * (100 - rate) / 100

  @spec apply_mdef_formula(number(), map(), map(), non_neg_integer(), boolean()) :: number()
  defp apply_mdef_formula(damage, defender, modifiers, ignore_mdef_rate, ignore_soft_mdef?) do
    # :mdef_rate is an additive percent delta on hard MDEF (Freeze's +25); the
    # skill-status family scales the defender's eMDEF. The attacker's equipment
    # ignore-mdef then bypasses a percent of the resulting hard MDEF.
    mdef_rate = Map.get(modifiers, :mdef_rate, 0)
    hard = trunc(defender.combat_stats.mdef * (100 + mdef_rate) / 100)
    hard = trunc(hard * (100 - ignore_mdef_rate) / 100)
    soft = if(ignore_soft_mdef?, do: 0, else: defender.combat_stats.soft_mdef)
    effective_hard = if hard == -100, do: -99, else: hard

    damage * (1000 + effective_hard) / (1000 + 10 * effective_hard) - soft
  end

  # Equipment bonuses read off `equip_modifiers`, present only on real
  # `%Combatant{}` structs; bare test maps get all-zero rates.
  @spec equipment_rates(map(), map(), pos_integer() | nil, atom()) :: map()
  defp equipment_rates(%Combatant{} = attacker, %Combatant{} = defender, skill_id, element) do
    %{
      attack: EquipmentBonuses.magic_attack_rates(attacker, defender, skill_id, element),
      taken: EquipmentBonuses.damage_taken_rates(defender, attacker, element),
      ignore_mdef: EquipmentBonuses.ignore_mdef_rate(attacker, defender.race)
    }
  end

  defp equipment_rates(_attacker, _defender, _skill_id, _element), do: @zero_equip_rates

  # :magic_damage_reduction is the percent of final magic damage the defender
  # shrugs off (SC_MDEF_RATE consumable family, rAthena battle.cpp:932). Clamped
  # to 0..100 before applying.
  @spec apply_magic_damage_reduction(number(), map()) :: number()
  defp apply_magic_damage_reduction(damage, modifiers) do
    reduction = Map.get(modifiers, :magic_damage_reduction, 0) |> max(0) |> min(100)
    damage * (100 - reduction) / 100
  end

  @spec combatant_modifiers(map()) :: map()
  defp combatant_modifiers(combatant) do
    {unit_type, unit_id} = get_unit_type_and_id(combatant)
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  @spec get_unit_type_and_id(map()) :: {atom(), integer()}
  defp get_unit_type_and_id(combatant) do
    case combatant.unit_type do
      :player -> {:player, combatant.unit_id}
      :mob -> {:mob, combatant.unit_id}
      _ -> {:unknown, combatant.unit_id}
    end
  end
end
