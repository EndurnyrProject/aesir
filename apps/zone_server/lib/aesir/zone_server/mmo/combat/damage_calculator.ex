defmodule Aesir.ZoneServer.Mmo.Combat.DamageCalculator do
  @moduledoc """
  Unified damage calculation system for all unit types.

  This module consolidates the duplicate damage calculation logic that was
  previously split between player and mob combat systems. It provides a
  single, authoritative implementation of the Renewal damage formula.

  ## Key Features

  - Unified damage calculation for all unit types (players, mobs, future units)
  - Composable modifier pipeline (size, race, element, status effects)
  - Renewal defense formula implementation
  - Critical hit processing

  ## Usage

      attacker_combatant = %{...}  # Standardized combatant structure
      defender_combatant = %{...}  # Standardized combatant structure

      case DamageCalculator.calculate_damage(attacker_combatant, defender_combatant) do
        {:ok, damage_result} ->
          # damage_result contains: %{damage: integer(), is_critical: boolean()}
        {:error, reason} ->
          # Handle error
      end
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers

  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @typedoc """
  Result of damage calculation containing final damage and critical hit status.
  """
  @type damage_result :: %{
          damage: non_neg_integer(),
          is_critical: boolean()
        }

  @typedoc """
  Standardized combatant structure for damage calculations.
  References the Combatant struct defined in the Combatant module.
  """
  @type combatant :: Combatant.t()

  @doc """
  Calculates damage from attacker to defender using unified Renewal formula.

  This is the main entry point for all damage calculations, regardless of
  unit type (player, mob, future units). The function handles:

  1. Base attack calculation (delegated to unit-specific logic)
  2. Modifier applications (size, race, element, status effects)
  3. Defense calculations (Renewal formula)
  4. Critical hit processing

  ## Parameters
    - attacker: Standardized combatant structure for attacker
    - defender: Standardized combatant structure for defender

  ## Returns
    - {:ok, damage_result} on success
    - {:error, reason} on failure

  ## Examples

      attacker = build_player_combatant(player_stats)
      defender = build_mob_combatant(mob_data)

      case DamageCalculator.calculate_damage(attacker, defender) do
        {:ok, %{damage: 150, is_critical: false}} ->
          apply_damage_to_target(defender, 150)
        {:error, reason} ->
          handle_damage_error(reason)
      end
  """
  @spec calculate_damage(combatant(), combatant()) :: {:ok, damage_result()} | {:error, atom()}
  def calculate_damage(attacker, defender), do: calculate_damage(attacker, defender, [])

  @doc """
  Calculates damage with skill modifiers.

  Options:
    - `:skill_ratio` - percent of base attack the skill deals (default `100`).
      A Bash at level 10 passes `400` for 400% weapon damage.
    - `:skip_crit` - when `true`, never rolls a critical (skills don't crit
      unless flagged). Default `false`.
    - `:bonus_atk` - flat ATK added after the skill-ratio step and before the
      modifier/defense pipeline (e.g. Envenom's `+15×level` mastery). Default `0`.
    - `:fixed_damage` - when set to an integer, short-circuits the entire
      pipeline and returns that flat value, bypassing base attack, skill ratio,
      modifiers, defense, criticals, and any flee/hit consideration (e.g. Stone
      Fling's fixed `50`). Default `nil`.
    - `:element` - overrides the attack element for this hit only, taking
      priority over both the weapon element and an `SC_WATK_ELEMENT` endow
      (e.g. Envenom's poison, Sand Attack's earth). Default `nil` (resolve
      normally).

  The skill ratio is applied to base attack before the size/race/element/status
  modifier pipeline. todo: faithful-enough Renewal ordering; card-vs-ratio
  edge cases are not modeled.
  """
  @spec calculate_damage(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :primary,
      &apply_defense_formula/3
    )
  end

  @doc """
  Calculates left-hand weapon damage without attacker cardfix or equipment DEF-ignore.

  The selected left hand supplies weapon ATK, refine, overrefine, subtype, and
  element. Global attacker modifiers and every defender-side channel remain active.
  Returns `{:error, :no_left_hand}` when no left-hand snapshot is available.
  """
  @spec calculate_secondary_hand_damage(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_secondary_hand_damage(%Combatant{left_hand: nil}, _defender, _opts),
    do: {:error, :no_left_hand}

  def calculate_secondary_hand_damage(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :secondary,
      &apply_defense_formula_without_equipment_def_ignore/3
    )
  end

  @doc """
  Calculates physical damage while omitting only attacker equipment cardfix.

  Equipment-derived DEF-ignore, skill and range rates, status/passive modifiers,
  and defender-side channels remain active.
  """
  @spec calculate_damage_ignoring_attacker_cards(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_ignoring_attacker_cards(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :ignore_attacker_cards,
      &apply_defense_formula/3
    )
  end

  @doc """
  Calculates physical skill damage while omitting the defender's status DEF.

  This restricted entry point preserves equipment DEF and the rest of the
  weapon-damage pipeline. It exists for skills whose mechanic explicitly
  ignores status DEF without exposing a general bypass option.
  """
  @spec calculate_damage_ignoring_status_def(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_ignoring_status_def(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :primary,
      &apply_defense_formula_ignoring_status_def/3
    )
  end

  @doc """
  Calculates physical skill damage using the simplified (flat) defense reduction.

  For a skill with simplified defense (e.g. Asura Strike), the renewal
  `Attack * (4000 + eDEF) / (4000 + eDEF*10)` curve is replaced by a flat
  subtraction of hard + soft DEF (`total_atk - (eDEF + sDEF)`). Every other
  channel - status DEF modifiers, equipment DEF-ignore, divine protection, phys
  damage reduction, and the min-1 clamp - is unchanged.
  """
  @spec calculate_damage_simple_defense(combatant(), combatant(), keyword()) ::
          {:ok, damage_result()} | {:error, atom()}
  def calculate_damage_simple_defense(attacker, defender, opts) do
    calculate_damage_with(
      attacker,
      defender,
      opts,
      :primary,
      &apply_defense_formula_simple/3
    )
  end

  defp calculate_damage_with(attacker, defender, opts, attack_path, defense_calculator) do
    case Keyword.get(opts, :fixed_damage) do
      nil -> calculate_pipeline_damage(attacker, defender, opts, attack_path, defense_calculator)
      fixed_damage -> {:ok, %{damage: fixed_damage, is_critical: false}}
    end
  end

  defp calculate_pipeline_damage(attacker, defender, opts, attack_path, defense_calculator) do
    attacker = select_weapon_hand(attacker, attack_path)
    skill_ratio = Keyword.get(opts, :skill_ratio, 100)
    bonus_atk = Keyword.get(opts, :bonus_atk, 0)

    with {:ok, base_atk} <- calculate_base_attack(attacker, opts),
         patk_atk = apply_patk_multiplier(base_atk, attacker),
         skilled_atk = div(patk_atk * skill_ratio, 100) + bonus_atk,
         {:ok, modified_atk} <-
           apply_modifier_pipeline(skilled_atk, attacker, defender, opts, attack_path),
         total_atk = modified_atk + demon_bane_bonus(attacker, defender),
         total_atk = total_atk + beast_bane_bonus(attacker, defender),
         total_atk = apply_res_reduction(total_atk, defender),
         {:ok, final_damage} <- defense_calculator.(total_atk, defender, attacker) do
      finalize_damage(final_damage, attacker, opts)
    end
  end

  # P.Atk (renewal 4th-job attacker stat): a percentage multiplier on base ATK
  # applied before the skill ratio. rAthena battle.cpp:5532.
  defp apply_patk_multiplier(base_atk, attacker) do
    patk = Map.get(attacker.combat_stats, :patk, 0)
    div(base_atk * (100 + patk), 100)
  end

  # Res (renewal 4th-job defender stat): a soft-capped reduction applied to
  # total ATK before the DEF formula. rAthena battle.cpp:5608.
  defp apply_res_reduction(total_atk, defender) do
    res = Map.get(defender.combat_stats, :res, 0)
    DamageShared.res_reduction(total_atk, res)
  end

  # Demon Bane (AL_DEMONBANE): flat ATK added before the defense formula when the
  # defender is undead/demon. Additive, unlike the multiplicative race modifier.
  defp demon_bane_bonus(attacker, defender) do
    RaceModifiers.demon_bane_atk(attacker, defender.race)
  end

  defp beast_bane_bonus(attacker, defender) do
    RaceModifiers.beast_bane_atk(attacker, defender.race)
  end

  # `:force_crit` guarantees the critical (Auto Counter's counter strike) and
  # wins over `:skip_crit`; otherwise the roll is skipped or rolled per opts.
  defp finalize_damage(damage, attacker, opts) do
    cond do
      Keyword.get(opts, :force_crit, false) -> apply_forced_critical_hit(damage, attacker)
      Keyword.get(opts, :skip_crit, false) -> {:ok, %{damage: damage, is_critical: false}}
      true -> apply_critical_hit(damage, attacker)
    end
  end

  @doc """
  Calculates base attack value based on unit type and stats.

  This function delegates to unit-specific base attack calculation logic
  while providing a unified interface.
  """
  @spec calculate_base_attack(combatant()) :: {:ok, integer()} | {:error, atom()}
  def calculate_base_attack(attacker), do: calculate_base_attack(attacker, [])

  @doc """
  Calculates base attack with optional narrow base replacement.

  `:base_damage` must be a non-negative integer. When present it replaces only
  the unit-specific base attack roll; P.Atk, skill ratio, combat modifiers,
  RES/DEF, minimum damage, and critical processing remain in the normal damage
  pipeline.

  `:shield_base` replaces a player attacker's weapon ATK and mastery with the
  pre-computed shield contribution. Other unit types ignore it.
  """
  @spec calculate_base_attack(combatant(), keyword()) :: {:ok, integer()} | {:error, atom()}
  def calculate_base_attack(attacker, opts) do
    case Keyword.fetch(opts, :base_damage) do
      {:ok, damage} when is_integer(damage) and damage >= 0 -> {:ok, damage}
      {:ok, _invalid} -> {:error, :invalid_base_damage}
      :error -> calculate_unit_base_attack(attacker, opts)
    end
  end

  defp calculate_unit_base_attack(%{unit_type: :player} = attacker, opts) do
    weapon_component =
      case Keyword.get(opts, :shield_base) do
        nil -> calculate_weapon_attack(attacker) + calculate_mastery_bonus(attacker)
        shield_base -> shield_base
      end

    {:ok, player_status_atk(attacker) + weapon_component}
  end

  defp calculate_unit_base_attack(%{unit_type: :homunculus} = attacker, _opts) do
    min_atk = attacker.combat_stats.atk_min
    max_atk = attacker.combat_stats.atk_max

    weapon_atk =
      if max_atk > min_atk,
        do: min_atk + :rand.uniform(max_atk - min_atk + 1) - 1,
        else: min_atk

    {:ok, attacker.combat_stats.atk + weapon_atk}
  end

  defp calculate_unit_base_attack(%{unit_type: :mob} = attacker, _opts) do
    # Renewal mob melee (rAthena status_base_atk_min/max + battle_calc_base_damage):
    # the weapon hit rolls uniformly across the 80%-120% band of the mob's ATK,
    # then the mob's base ATK (STR + base level) is added flat.
    atk = attacker.combat_stats.atk
    atk_min = div(atk * 80, 100)
    atk_max = div(atk * 120, 100)

    weapon_atk =
      if atk_max > atk_min do
        atk_min + :rand.uniform(atk_max - atk_min) - 1
      else
        atk_min
      end

    batk = attacker.base_stats.str + attacker.progression.base_level

    {:ok, weapon_atk + batk}
  end

  defp calculate_unit_base_attack(_attacker, _opts), do: {:error, :unknown_unit_type}

  # Player stat-derived base attack (rAthena status->batk): the weapon-independent
  # portion the shield damage base builds on. (STR*2) + (DEX/5) + (LUK/3) +
  # base_level/4 + 5*POW.
  defp player_status_atk(%{base_stats: stats, progression: progression}) do
    stats.str * 2 +
      div(stats.dex, 5) +
      div(stats.luk, 3) +
      div(progression.base_level, 4) +
      5 * Map.get(stats, :pow, 0)
  end

  @doc """
  Applies the composable modifier pipeline to damage.

  Modifiers are applied in this order:
  1. Size modifiers
  2. Race modifiers
  3. Element modifiers
  4. Status effect modifiers

  `opts` accepts `:element` to force the attack element for this call (see
  `calculate_damage/3`), taking priority over both the weapon element and any
  `attack_element` status modifier. `:skill_id` scopes the `{:skill_atk, id}`
  equipment family to the current skill. The mounted-spear size-modifier
  override is read from the attacker combatant's `:riding` flag.

  After the size/race/element/status steps, the attacker's equipment damage
  families (race+class, element, size, skill) each apply as their own
  sequential multiplicative step, then the defender's equipment damage-taken
  families (race+class, element, size) apply as reductions.
  """
  @spec apply_modifier_pipeline(integer(), combatant(), combatant(), keyword()) :: {:ok, number()}
  def apply_modifier_pipeline(base_damage, attacker, defender, opts \\ []) do
    apply_modifier_pipeline(base_damage, attacker, defender, opts, :primary)
  end

  defp apply_modifier_pipeline(base_damage, attacker, defender, opts, attack_path) do
    {unit_type, unit_id} = get_unit_type_and_id(attacker)
    attacker_modifiers = ModifierCalculator.get_all_modifiers(unit_type, unit_id)
    forced_element = Keyword.get(opts, :element)
    skill_id = Keyword.get(opts, :skill_id)
    attack_element = forced_element || resolve_attack_element(attacker, attacker_modifiers)

    total_atk =
      base_damage
      |> apply_size_modifier(attacker, defender)
      |> apply_element_modifier(attack_element, defender, attacker_modifiers)
      |> apply_status_effect_damage_modifiers(attacker_modifiers)
      |> apply_equipment_attack_families(
        attacker,
        defender,
        skill_id,
        attack_element,
        attack_path
      )
      |> apply_equipment_taken_families(attacker, defender, skill_id, attack_element, opts)

    {:ok, total_atk}
  end

  @doc """
  Applies the Renewal defense reduction formula.

  Formula: Attack * (4000 + eDEF) / (4000 + eDEF*10) - sDEF

  Where:
  - eDEF = equipment/hard defense
  - sDEF = soft defense (VIT-based)
  """
  @spec apply_defense_formula(number(), combatant(), combatant() | nil) :: {:ok, integer()}
  def apply_defense_formula(total_atk, defender, attacker \\ nil),
    do: apply_defense_formula(total_atk, defender, attacker, :apply_status_def)

  defp apply_defense_formula_ignoring_status_def(total_atk, defender, attacker),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        :ignore_status_def,
        :apply_equipment_def_ignore
      )

  defp apply_defense_formula_without_equipment_def_ignore(total_atk, defender, attacker),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        :apply_status_def,
        :omit_equipment_def_ignore
      )

  defp apply_defense_formula_simple(total_atk, defender, attacker),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        :apply_status_def,
        :apply_equipment_def_ignore,
        :simple
      )

  defp apply_defense_formula(total_atk, defender, attacker, status_def_mode),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        status_def_mode,
        :apply_equipment_def_ignore
      )

  defp apply_defense_formula(total_atk, defender, attacker, status_def_mode, def_ignore_mode),
    do:
      apply_defense_formula(
        total_atk,
        defender,
        attacker,
        status_def_mode,
        def_ignore_mode,
        :renewal
      )

  defp apply_defense_formula(
         total_atk,
         defender,
         attacker,
         status_def_mode,
         def_ignore_mode,
         def_formula
       ) do
    hard_def = ignore_hard_def(defender.combat_stats.def, attacker, defender, def_ignore_mode)

    soft_def =
      case status_def_mode do
        :apply_status_def ->
          calculate_soft_defense(defender) + divine_protection_bonus(attacker, defender)

        :ignore_status_def ->
          0
      end

    {unit_type, unit_id} = get_unit_type_and_id(defender)
    modifiers = ModifierCalculator.get_all_modifiers(unit_type, unit_id)

    # Apply status effect defense modifiers
    {modified_hard_def, calculated_soft_def} =
      apply_status_effect_defense_modifiers(hard_def, soft_def, modifiers)

    # Load-bearing: status-effect modifiers can turn the zeroed soft-DEF input
    # back into a positive value, so ignore mode must clamp again here.
    modified_soft_def =
      if status_def_mode == :ignore_status_def, do: 0, else: calculated_soft_def

    # Apply Renewal defense reduction formula
    # Handle edge case where hard_def = -400 (causes division by zero)
    effective_hard_def = if modified_hard_def == -400, do: -399, else: modified_hard_def

    base_damage =
      defense_base_damage(def_formula, total_atk, effective_hard_def, modified_soft_def)

    final_damage =
      base_damage
      |> apply_phys_damage_reduction(modifiers)
      |> DamageShared.clamp_min_one()

    Logger.debug(
      "Defense calculation: total_atk=#{trunc(total_atk)}, hard_def=#{modified_hard_def}, soft_def=#{modified_soft_def}, final_damage=#{final_damage}"
    )

    {:ok, final_damage}
  end

  # Renewal DEF curve vs. the simplified flat subtraction: the simple path drops
  # hard + soft DEF as a flat value, completely bypassing the renewal reduction
  # formula.
  defp defense_base_damage(:renewal, total_atk, hard_def, soft_def),
    do: total_atk * (4000 + hard_def) / (4000 + 10 * hard_def) - soft_def

  defp defense_base_damage(:simple, total_atk, hard_def, soft_def),
    do: total_atk - (hard_def + soft_def)

  @doc """
  Applies critical hit calculation to final damage.
  """
  @spec apply_critical_hit(integer(), combatant()) :: {:ok, CriticalHits.critical_result()}
  def apply_critical_hit(base_damage, attacker) do
    # Carry combat_stats so CriticalHits can read `crate` (renewal crit-damage
    # scaling) and equip_modifiers for the equipment critical damage percent.
    # Non-player attackers lack a crate key and carry no equipment -> CriticalHits
    # defaults both to 0, landing on the x1.4 non-player branch.
    attacker_for_crit = %{
      luk: attacker.base_stats.luk,
      critical: computed_critical_rate(attacker),
      combat_stats: attacker.combat_stats,
      equip_modifiers: attacker.equip_modifiers
    }

    critical_result = CriticalHits.calculate_critical_hit(attacker_for_crit, base_damage)

    Logger.debug(
      "Critical hit check: base_damage=#{base_damage}, final_damage=#{critical_result.damage}#{if critical_result.is_critical, do: " (CRITICAL)", else: ""}"
    )

    {:ok, critical_result}
  end

  @doc """
  Applies the Renewal critical multiplier unconditionally, flagging the hit as a
  critical without rolling.

  For effects that deal a guaranteed critical regardless of the attacker's crit
  rate (Auto Counter's counter strike). Reuses `CriticalHits.apply_critical_damage/2`
  so the CRate and equipment critical-damage channels stay identical to a rolled
  critical.
  """
  @spec apply_forced_critical_hit(integer(), combatant()) :: {:ok, CriticalHits.critical_result()}
  def apply_forced_critical_hit(base_damage, attacker) do
    attacker_for_crit = %{
      combat_stats: attacker.combat_stats,
      equip_modifiers: attacker.equip_modifiers
    }

    {:ok,
     %{
       damage: CriticalHits.apply_critical_damage(base_damage, attacker_for_crit),
       is_critical: true,
       critical_rate: 1_000
     }}
  end

  defp computed_critical_rate(%{base_stats: %{luk: luk}, combat_stats: %{critical: critical}})
       when is_integer(luk) and is_integer(critical) do
    base_critical = div(luk, 3)

    CriticalHits.calculate_critical_rate_from_luk(luk) + (critical - base_critical) * 10
  end

  defp computed_critical_rate(_attacker), do: nil

  # Private helper functions

  defp select_weapon_hand(
         %Combatant{unit_type: :player, right_hand: right, left_hand: left} = attacker,
         attack_path
       )
       when not is_nil(right) or not is_nil(left) do
    selected = if attack_path == :secondary, do: left, else: right || left
    shared_atk = attacker.combat_stats.atk - hand_atk(right) - hand_atk(left)

    combat_stats =
      attacker.combat_stats
      |> Map.put(:atk, shared_atk + hand_atk(selected))
      |> Map.put(:overrefine_band, hand_overrefine_band(selected))

    weapon =
      if attack_path == :secondary,
        do: selected_weapon(attacker.weapon, selected),
        else: attacker.weapon

    %{attacker | combat_stats: combat_stats, weapon: weapon}
  end

  defp select_weapon_hand(attacker, _attack_path), do: attacker

  defp hand_atk(nil), do: 0
  defp hand_atk(hand), do: hand.base_atk + hand.refine_atk

  defp hand_overrefine_band(nil), do: 0
  defp hand_overrefine_band(hand), do: hand.overrefine_band

  defp selected_weapon(weapon, nil), do: weapon

  defp selected_weapon(weapon, hand) do
    %{weapon | type: hand.subtype, element: hand.element}
  end

  defp calculate_weapon_attack(%{unit_type: :player} = attacker) do
    # Renewal player weapon ATK: the equipped weapon's accumulated flat ATK
    # (combat_stats.atk, includes the refine bonus) rolls uniformly across an
    # 80%-120% weapon-level variance band, mirroring the mob variance shape
    # (calculate_base_attack/1 for :mob). Not a full port of rAthena's
    # battle_calc_weapon_attack (no eatk/statusatk/star-crumb buckets).
    atk = attacker.combat_stats.atk
    atk_min = div(atk * 80, 100)
    atk_max = div(atk * 120, 100)

    weapon_attack =
      cond do
        Map.get(attacker.combat_stats, :max_weapon_damage, false) ->
          atk_max

        atk_max > atk_min ->
          atk_min + :rand.uniform(atk_max - atk_min) - 1

        true ->
          atk_min
      end

    # Overrefine (rAthena battle.cpp:2413-2420): a per-hit rnd()%band + 1 extra.
    overrefine_band = Map.get(attacker.combat_stats, :overrefine_band, 0)
    overrefine_extra = DamageShared.overrefine_roll(overrefine_band)

    max(1, weapon_attack + overrefine_extra)
  end

  defp calculate_mastery_bonus(attacker), do: attacker.combat_stats.passive_atk

  defp calculate_soft_defense(%{unit_type: :player} = defender) do
    # Renewal: soft_def = vit (direct VIT value)
    defender.base_stats.vit
  end

  defp calculate_soft_defense(%{unit_type: :homunculus} = defender) do
    defender.combat_stats.soft_def
  end

  defp calculate_soft_defense(%{unit_type: :mob}) do
    # Mobs typically don't have separate soft defense calculation
    0
  end

  defp calculate_soft_defense(%{unit_type: :skill_unit} = defender) do
    defender.combat_stats.soft_def
  end

  # Reduces the defender's hard DEF by the attacker's equipment
  # ignore-def-by-race/class percent before the renewal formula. A nil attacker
  # (legacy 2-arity call) or a 0 rate leaves hard DEF bit-identical.
  defp ignore_hard_def(hard_def, _attacker, _defender, :omit_equipment_def_ignore),
    do: hard_def

  defp ignore_hard_def(hard_def, nil, _defender, :apply_equipment_def_ignore), do: hard_def

  defp ignore_hard_def(hard_def, attacker, defender, :apply_equipment_def_ignore) do
    rate = EquipmentBonuses.ignore_def_rate(attacker, defender)
    div(hard_def * (100 - rate), 100)
  end

  # Divine Protection (AL_DP): flat soft-DEF added to the defender when the
  # attacker is undead/demon. nil attacker (e.g. the legacy 2-arity call) means
  # no attacker context, so no Divine Protection is applied.
  defp divine_protection_bonus(nil, _defender), do: 0

  defp divine_protection_bonus(attacker, defender) do
    RaceModifiers.divine_protection_def(defender, attacker.race)
  end

  # Modifier application functions (unified from original Combat module)

  defp apply_element_modifier(damage, attack_element, defender, attacker_modifiers) do
    DamageShared.apply_element(damage, attack_element, defender, attacker_modifiers)
  end

  # Attacker percent damage families. Each family (race+class, element, size,
  # skill, long-attack, short-attack) is one sequential multiplicative step. The
  # two range families are mutually exclusive — the weapon is either ranged or
  # not — so only one of them is ever non-zero. Every contributor to a family
  # sums into a single accumulator before the multiply, so passives (Dragonology)
  # and equipment never compound against each other — mirroring the magic
  # pipeline's cardfix model. A family summing to 0 is identity, preserving the
  # float damage untouched.
  defp apply_equipment_attack_families(
         damage,
         attacker,
         defender,
         skill_id,
         attack_element,
         attack_path
       ) do
    %{race_class: card_race_class, element: card_element, size: card_size, skill: skill} =
      EquipmentBonuses.attack_rates(attacker, defender, skill_id, attack_element)

    {card_race_class, card_element, card_size} =
      case attack_path do
        path when path in [:secondary, :ignore_attacker_cards] -> {0, 0, 0}
        :primary -> {card_race_class, card_element, card_size}
      end

    race_class =
      card_race_class + RaceModifiers.dragonology_atk_rate(attacker, defender.race)

    damage
    |> apply_family_step(race_class)
    |> apply_family_step(card_element)
    |> apply_family_step(card_size)
    |> apply_family_step(skill)
    |> apply_family_step(EquipmentBonuses.long_atk_rate(attacker))
    |> apply_family_step(EquipmentBonuses.short_atk_rate(attacker))
  end

  # Defender percent damage-taken families, read off the defender's own
  # equipment and status effects, keyed on the attacker's traits / the effective
  # attack element. Dragonology's resist rate sums into the race+class family like
  # any other contributor; the defender's status resist keys (subele/subrace) sum
  # into the element/race families through EquipmentBonuses. The ranged family is
  # a taken-rate step gated on the hit being ranged — the per-hit `:ranged` opt
  # (thrown-weapon skills), a ranged weapon class, or a long attack range (ranged
  # mobs) — matching the `is_short` determination used at hit delivery. Each
  # reduction family is floored at the min-1 damage convention.
  defp apply_equipment_taken_families(damage, attacker, defender, skill_id, attack_element, opts) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)
    status_modifiers = ModifierCalculator.get_all_modifiers(unit_type, unit_id)

    %{race_class: race_class, element: element, size: size, skill: skill} =
      EquipmentBonuses.damage_taken_rates(
        defender,
        attacker,
        attack_element,
        status_modifiers,
        skill_id
      )

    race_class = race_class + RaceModifiers.dragonology_resist_rate(defender, attacker.race)

    ranged =
      EquipmentBonuses.ranged_damage_taken_rate(
        defender,
        status_modifiers,
        ranged_hit?(attacker, opts)
      )

    long_def =
      EquipmentBonuses.long_range_defense_rate(
        defender,
        status_modifiers,
        ranged_hit?(attacker, opts)
      )

    damage
    |> apply_taken_step(race_class)
    |> apply_taken_step(element)
    |> apply_taken_step(size)
    |> apply_taken_step(skill)
    |> apply_taken_step(long_def)
    |> apply_taken_rate_step(ranged)
  end

  defp ranged_hit?(attacker, opts) do
    Keyword.get(opts, :ranged, false) or
      attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?() or
      Map.get(attacker, :attack_range, 1) > 3
  end

  defp apply_family_step(damage, 0), do: damage
  defp apply_family_step(damage, sum), do: div(trunc(damage) * (100 + sum), 100)

  defp apply_taken_step(damage, 0), do: damage
  defp apply_taken_step(damage, sum), do: max(1, div(trunc(damage) * (100 - sum), 100))

  defp apply_taken_rate_step(damage, 0), do: damage
  defp apply_taken_rate_step(damage, sum), do: max(1, div(trunc(damage) * (100 + sum), 100))

  defp resolve_attack_element(attacker, attacker_modifiers) do
    Map.get_lazy(attacker_modifiers, :attack_element, fn ->
      Map.get(attacker.weapon, :element, :neutral)
    end)
  end

  defp apply_size_modifier(damage, %{combat_stats: %{ignore_size_penalty: true}}, _defender),
    do: damage

  defp apply_size_modifier(damage, attacker, defender) do
    # `bNoSizeFix` on the attacker's equipment ignores the size modifier entirely,
    # like the status-driven `ignore_size_penalty` above.
    if Map.get(Map.get(attacker, :equip_modifiers, %{}), :no_size_fix, 0) > 0 do
      damage
    else
      modifier = SizeModifiers.get_modifier(attacker.weapon.type, defender.size, attacker.riding)
      damage * modifier / 100
    end
  end

  defp apply_status_effect_damage_modifiers(damage, modifiers) do
    damage_bonus = Map.get(modifiers, :damage_bonus, 0)
    atk_bonus = Map.get(modifiers, :atk_bonus, 0)
    # :watk is flat weapon ATK granted by statuses (SC_LOUD / Crazy Uproar, Impositio
    # Manus); it is added as flat ATK alongside :atk_bonus / :damage_bonus.
    weapon_atk = Map.get(modifiers, :watk, 0)
    # :atk_rate is an additive percent delta on physical damage (SC_INCATKRATE,
    # Curse's -25, Provoke). Applied after flat ATK, before the damage multiplier.
    atk_rate = Map.get(modifiers, :atk_rate, 0)

    flat_atk = damage_bonus + atk_bonus + weapon_atk
    scaled_atk = (damage + flat_atk) * (100 + atk_rate) / 100

    DamageShared.apply_damage_multiplier(scaled_atk, modifiers)
  end

  defp apply_status_effect_defense_modifiers(hard_def, soft_def, modifiers) do
    hard_def_bonus = Map.get(modifiers, :def_bonus, 0)
    soft_def_bonus = Map.get(modifiers, :vit_bonus, 0)
    # :def_rate is an additive percent delta on hard DEF (Freeze's -50, Provoke,
    # SignumCrucis, DeadlyPoison); the skill-status family scales eDEF.
    # :def2_rate is the soft-DEF analogue (rAthena status_calc_def2 percent
    # statuses: Angelus, Provoke, Poison).
    def_rate = Map.get(modifiers, :def_rate, 0)
    def2_rate = Map.get(modifiers, :def2_rate, 0)

    defense_multiplier = 1.0 + Map.get(modifiers, :defense_multiplier, 0.0)

    modified_hard_def =
      trunc((hard_def + hard_def_bonus) * defense_multiplier * (100 + def_rate) / 100)

    modified_soft_def =
      trunc((soft_def + soft_def_bonus) * defense_multiplier * (100 + def2_rate) / 100)

    {modified_hard_def, modified_soft_def}
  end

  # :phys_damage_reduction is the percent of final physical damage the defender
  # shrugs off (SC_DEF_RATE consumable family, rAthena battle.cpp:1151). Clamped
  # to 0..100 before applying.
  defp apply_phys_damage_reduction(damage, modifiers) do
    reduction = clamp_reduction(Map.get(modifiers, :phys_damage_reduction, 0))
    damage * (100 - reduction) / 100
  end

  defp clamp_reduction(value), do: value |> max(0) |> min(100)

  defp get_unit_type_and_id(combatant) do
    case combatant.unit_type do
      :player -> {:player, combatant.unit_id}
      :mob -> {:mob, combatant.unit_id}
      :homunculus -> {:homunculus, combatant.unit_id}
      _ -> {:unknown, combatant.unit_id}
    end
  end
end
