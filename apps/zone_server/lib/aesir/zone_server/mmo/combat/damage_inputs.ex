defmodule Aesir.ZoneServer.Mmo.Combat.DamageInputs do
  @moduledoc """
  Shared input preparation for ordinary combat and skill-owned calculations.

  Resolves existing snapshot components, rolls and defense channels without
  selecting skill recipes or delivering damage.
  """
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @magic_attack_flag BattleFlags.build(:magic, :long, true)
  @zero_equip_rates %{
    attack: %{race: 0, race2: 0, class: 0, element_target: 0, size: 0, atk_ele: 0, skill: 0},
    taken: %{race: 0, race2: 0, class: 0, element: 0, size: 0, skill: 0},
    ignore_mdef: 0
  }

  @doc "Rolls selected player components without reconstructing display ATK."
  @spec player_attack_parts(map(), keyword(), atom(), boolean()) :: PhysicalAttack.parts()
  def player_attack_parts(attacker, opts, attack_path, critical?) do
    snapshot = attacker.combat_stats.physical_attack

    right = Map.get(attacker, :right_hand)
    left = Map.get(attacker, :left_hand)
    hand = if attack_path == :secondary, do: left, else: right || left

    parts = %{
      status_atk: snapshot.status_atk,
      flat_atk: snapshot.flat_atk,
      mastery_atk: snapshot.mastery_atk,
      hand: if(hand, do: hand.slot, else: :right_hand),
      source: :weapon,
      weapon_atk: 0,
      refine_atk: 0,
      overrefine_atk: 0
    }

    case Keyword.get(opts, :shield_base) do
      nil -> roll_player_weapon(parts, snapshot, hand, attacker.combat_stats, critical?)
      shield -> %{parts | source: :shield, weapon_atk: shield, flat_atk: 0, mastery_atk: 0}
    end
  end

  defp roll_player_weapon(parts, _snapshot, nil, _combat_stats, _critical?), do: parts

  defp roll_player_weapon(parts, snapshot, hand, combat_stats, critical?) do
    inputs = %{
      base_atk: hand.base_atk,
      refine_atk: hand.refine_atk,
      weapon_level: hand.weapon_level,
      primary_stat:
        if(WeaponTypes.is_ranged?(hand.subtype), do: snapshot.dex, else: snapshot.str),
      dex: snapshot.dex,
      arrow?: WeaponTypes.requires_ammo?(hand.subtype),
      critical?: critical?,
      max_weapon_damage?: Map.get(combat_stats, :max_weapon_damage, false)
    }

    {minimum, maximum} = Mechanics.physical_attack().weapon_bounds(inputs)

    %{
      parts
      | weapon_atk: DamageShared.roll(minimum, maximum + 1),
        refine_atk: hand.refine_atk,
        overrefine_atk: DamageShared.overrefine_roll(hand.overrefine_band)
    }
  end

  @doc "Rolls the existing non-player base attack representation."
  @spec non_player_base_attack(map()) :: {:ok, integer()} | {:error, atom()}
  def non_player_base_attack(%{unit_type: :homunculus} = attacker) do
    min_atk = attacker.combat_stats.atk_min
    max_atk = attacker.combat_stats.atk_max

    weapon_atk =
      if max_atk > min_atk,
        do: min_atk + :rand.uniform(max_atk - min_atk + 1) - 1,
        else: min_atk

    {:ok, attacker.combat_stats.atk + weapon_atk}
  end

  def non_player_base_attack(%{unit_type: :mob} = attacker) do
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

  def non_player_base_attack(_attacker), do: {:error, :unknown_unit_type}

  @doc "Resolves physical DEF using the existing status and equipment omission modes."
  @spec physical_defense(map(), map() | nil, atom(), atom(), map()) :: {integer(), integer()}
  def physical_defense(defender, attacker, status_def_mode, def_ignore_mode, modifiers) do
    {unit_type, unit_id} = get_unit_type_and_id(defender)

    case StatusStorage.get_status(unit_type, unit_id, :sc_defset) do
      %{val1: value} when is_integer(value) ->
        hard_def = ignore_hard_def(value, attacker, defender, def_ignore_mode)
        soft_def = if status_def_mode == :ignore_status_def, do: 0, else: value
        {hard_def, soft_def}

      _missing ->
        ordinary_defense_values(
          defender,
          attacker,
          status_def_mode,
          def_ignore_mode,
          modifiers
        )
    end
  end

  defp ordinary_defense_values(
         defender,
         attacker,
         status_def_mode,
         def_ignore_mode,
         modifiers
       ) do
    hard_def = ignore_hard_def(defender.combat_stats.def, attacker, defender, def_ignore_mode)

    soft_def =
      if status_def_mode == :ignore_status_def do
        0
      else
        calculate_soft_defense(defender) + divine_protection_bonus(attacker, defender)
      end

    {modified_hard_def, modified_soft_def} =
      apply_status_effect_defense_modifiers(hard_def, soft_def, modifiers)

    if status_def_mode == :ignore_status_def do
      {modified_hard_def, 0}
    else
      {modified_hard_def, modified_soft_def}
    end
  end

  defp calculate_soft_defense(%{unit_type: :player} = defender) do
    rate = max(0, 100 + Map.get(defender.equip_modifiers, :def2_rate, 0))

    soft_def =
      Map.get(defender.combat_stats, :soft_def) ||
        Mechanics.player_formulas().soft_def(%{
          vit: defender.base_stats.vit,
          agi: defender.base_stats.agi,
          base_level: defender.progression.base_level
        })

    div(soft_def * rate, 100)
  end

  defp calculate_soft_defense(%{unit_type: :homunculus} = defender) do
    defender.combat_stats.soft_def
  end

  defp calculate_soft_defense(%{unit_type: :mob} = defender) do
    defender.combat_stats.soft_def
  end

  defp calculate_soft_defense(%{unit_type: :skill_unit} = defender) do
    defender.combat_stats.soft_def
  end

  defp ignore_hard_def(hard_def, _attacker, _defender, :omit_equipment_def_ignore),
    do: hard_def

  defp ignore_hard_def(hard_def, nil, _defender, :apply_equipment_def_ignore), do: hard_def

  defp ignore_hard_def(hard_def, attacker, defender, :apply_equipment_def_ignore) do
    rate = EquipmentBonuses.ignore_def_rate(attacker, defender)
    div(hard_def * (100 - rate), 100)
  end

  defp divine_protection_bonus(nil, _defender), do: 0

  defp divine_protection_bonus(attacker, defender) do
    RaceModifiers.divine_protection_def(defender, attacker.race)
  end

  defp apply_status_effect_defense_modifiers(hard_def, soft_def, modifiers) do
    hard_def_bonus = Map.get(modifiers, :def_bonus, 0)
    soft_def_bonus = Map.get(modifiers, :vit_bonus, 0)
    def_rate = Map.get(modifiers, :def_rate, 0)
    def2_rate = Map.get(modifiers, :def2_rate, 0)

    defense_multiplier = 1.0 + Map.get(modifiers, :defense_multiplier, 0.0)

    modified_hard_def =
      trunc((hard_def + hard_def_bonus) * defense_multiplier * (100 + def_rate) / 100)

    modified_soft_def =
      trunc((soft_def + soft_def_bonus) * defense_multiplier * (100 + def2_rate) / 100)

    {modified_hard_def, modified_soft_def}
  end

  @doc "Captures magic channels using status maps already read by the caller."
  @spec magic_context(map(), map(), keyword(), map(), map()) :: MagicDamage.context()
  def magic_context(attacker, defender, opts, modifiers, defender_modifiers) do
    element = Keyword.get(opts, :element, :neutral)
    skill_id = Keyword.get(opts, :skill_id)
    equip = equipment_rates(attacker, defender, defender_modifiers, skill_id, element)
    {hard, soft} = mdef_values(defender, defender_modifiers)

    attack = %{
      size: equip.attack.size + status_rate(modifiers, :magic_addsize, Map.get(defender, :size)),
      race2: equip.attack.race2,
      element_target:
        equip.attack.element_target +
          status_rate(modifiers, :magic_addele, defender_element(defender)),
      atk_ele: equip.attack.atk_ele,
      race:
        equip.attack.race + status_rate(modifiers, :magic_addrace, Map.get(defender, :race)) +
          RaceModifiers.dragonology_matk_rate(attacker, Map.get(defender, :race)),
      class: equip.attack.class
    }

    taken = %{
      element: equip.taken.element,
      size: equip.taken.size,
      race2: equip.taken.race2,
      race:
        equip.taken.race +
          RaceModifiers.dragonology_resist_rate(defender, Map.get(attacker, :race)),
      class: equip.taken.class,
      magic: Map.get(defender_modifiers, :magic_damage_reduction, 0)
    }

    %{
      attack: attack,
      taken: taken,
      skill_ratio: Keyword.get(opts, :skill_ratio, 100),
      bonus_matk: Keyword.get(opts, :bonus_matk, 0),
      skill_atk_rate: equip.attack.skill,
      skill_taken_rate: equip.taken.skill,
      matk_rate: Map.get(modifiers, :matk_rate, 0),
      damage_multiplier: Map.get(modifiers, :damage_multiplier, 0),
      smatk: Map.get(attacker.combat_stats, :smatk, 0),
      mres: Map.get(defender.combat_stats, :mres, 0),
      hard_mdef: hard,
      soft_mdef: soft,
      ignore_mdef_rate: equip.ignore_mdef,
      ignore_mdef?: Keyword.get(opts, :ignore_mdef, false),
      element_modifier: DamageShared.apply_element(1, element, defender, modifiers)
    }
  end

  @doc "Rolls the half-open MATK band, falling back to its deterministic scalar."
  @spec roll_matk(map()) :: non_neg_integer()
  def roll_matk(combat_stats) do
    DamageShared.roll(
      Map.get(combat_stats, :matk_min, combat_stats.matk),
      Map.get(combat_stats, :matk_max, combat_stats.matk)
    )
  end

  defp status_rate(modifiers, family, value) do
    Map.get(modifiers, {family, value}, 0) + Map.get(modifiers, {family, :all}, 0)
  end

  defp defender_element(defender) do
    case Map.get(defender, :element, :neutral) do
      {element, _level} -> element
      element -> element
    end
  end

  defp mdef_values(defender, modifiers) do
    {unit_type, unit_id} = magic_unit_ref(defender)

    case StatusStorage.get_status(unit_type, unit_id, :sc_mdefset) do
      %{val1: value} when is_integer(value) ->
        {value, value}

      _missing ->
        mdef_rate = Map.get(modifiers, :mdef_rate, 0)
        hard = trunc(defender.combat_stats.mdef * (100 + mdef_rate) / 100)
        {hard, defender.combat_stats.soft_mdef}
    end
  end

  defp equipment_rates(
         %Combatant{} = attacker,
         %Combatant{} = defender,
         modifiers,
         skill_id,
         element
       ) do
    %{
      attack: EquipmentBonuses.magic_attack_rates(attacker, defender, skill_id, element),
      taken:
        EquipmentBonuses.magic_defense_rates(
          defender,
          attacker,
          element,
          modifiers,
          skill_id,
          @magic_attack_flag
        ),
      ignore_mdef: EquipmentBonuses.ignore_mdef_rate(attacker, defender)
    }
  end

  defp equipment_rates(_attacker, _defender, _modifiers, _skill_id, _element),
    do: @zero_equip_rates

  defp magic_unit_ref(%{unit_type: type, unit_id: id}) when type in [:player, :mob],
    do: {type, id}

  defp magic_unit_ref(%{unit_id: id}), do: {:unknown, id}

  defp get_unit_type_and_id(%{unit_type: type, unit_id: id})
       when type in [:player, :mob, :homunculus], do: {type, id}

  defp get_unit_type_and_id(%{unit_id: id}), do: {:unknown, id}
end
