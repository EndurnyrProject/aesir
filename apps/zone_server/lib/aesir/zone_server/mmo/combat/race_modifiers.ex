defmodule Aesir.ZoneServer.Mmo.Combat.RaceModifiers do
  @moduledoc """
  Race-based damage modifier system based on rAthena implementation.

  This module handles race-specific damage bonuses that come from:
  - Weapon cards that provide race-specific damage
  - Skills that have race-specific effects
  - Equipment that enhances damage vs certain races

  Race types in Ragnarok Online:
  - :formless - Slimes, plants, and other basic life forms
  - :undead - Undead monsters and players
  - :brute - Animal-like monsters  
  - :plant - Plant monsters
  - :insect - Bug-type monsters
  - :fish - Aquatic monsters
  - :demon - Demonic monsters
  - :demi_human - Human-like monsters and players
  - :angel - Holy/angelic monsters
  - :dragon - Dragon-type monsters
  - :boss - Special boss monsters (receives different modifiers)
  """

  @type race ::
          :formless
          | :undead
          | :brute
          | :plant
          | :insect
          | :fish
          | :demon
          | :demi_human
          | :angel
          | :dragon
          | :boss

  # Races against which Demon Bane / Divine Protection apply. Only mobs carry
  # these, so both bonuses are PvE-only in practice.
  @undead_demon [:undead, :demon]

  @doc """
  Demon Bane (AL_DEMONBANE) additive physical ATK bonus.

  Returns the flat ATK added before defense when the defender's race is undead
  or demon, matching renewal rAthena `battle_addmastery`
  (`battle.cpp`): `level * (base_level / 20.0 + 3.0)` truncated to an integer.
  Returns `0` when the attacker has no Demon Bane level or the defender is
  neither undead nor demon.
  """
  @spec demon_bane_atk(map(), race()) :: non_neg_integer()
  def demon_bane_atk(
        %{demon_bane_level: level, progression: %{base_level: base_level}},
        defender_race
      )
      when level > 0 and defender_race in @undead_demon do
    trunc(level * (base_level / 20.0 + 3.0))
  end

  def demon_bane_atk(_attacker, _defender_race), do: 0

  @doc """
  Divine Protection (AL_DP) additive soft-DEF (VIT-DEF) bonus.

  Returns the flat soft defense added to the defender when the attacker's race
  is undead or demon, matching renewal rAthena `battle_calc_defense`
  (`battle.cpp`): `(base_level / 25.0 + 3.0) * level + 0.5` truncated to an
  integer. Returns `0` when the defender has no Divine Protection level or the
  attacker is neither undead nor demon.
  """
  @spec divine_protection_def(map(), race()) :: non_neg_integer()
  def divine_protection_def(
        %{divine_protection_level: level, progression: %{base_level: base_level}},
        attacker_race
      )
      when level > 0 and attacker_race in @undead_demon do
    trunc((base_level / 25.0 + 3.0) * level + 0.5)
  end

  def divine_protection_def(_defender, _attacker_race), do: 0

  @doc """
  Gets the damage modifier for attacking a specific race.

  This function would typically check:
  1. Weapon cards equipped by attacker
  2. Racial damage bonuses from equipment  
  3. Skill-based racial bonuses
  4. Any temporary buffs affecting racial damage

  ## Parameters
    - attacker_data: Map containing attacker's equipment/skills/buffs
    - defender_race: Race of the defending target

  ## Returns
    - Float representing the damage modifier (1.0 = no change)
  """
  @spec get_modifier(map(), race()) :: float()
  def get_modifier(_attacker_data, defender_race) do
    base_modifier = 1.0

    # TODO: Implement weapon card system
    # card_modifier = calculate_card_modifier(attacker_data.weapon_cards, defender_race)

    # TODO: Implement equipment bonuses
    # equipment_modifier = calculate_equipment_modifier(attacker_data.equipment, defender_race)

    # TODO: Implement skill bonuses
    # skill_modifier = calculate_skill_modifier(attacker_data.skills, defender_race)

    # For now, just apply basic boss resistance
    boss_modifier = if defender_race == :boss, do: apply_boss_resistance(), else: 1.0

    base_modifier * boss_modifier
  end

  @doc """
  Gets the default race for players.
  """
  @spec player_race() :: race()
  def player_race, do: :demi_human

  @doc """
  Checks if a race is considered undead.
  Useful for special mechanics that affect undead differently.
  """
  @spec undead?(race()) :: boolean()
  def undead?(:undead), do: true
  def undead?(_), do: false

  @doc """
  Checks if a race is considered a boss.
  Bosses typically have special resistances and mechanics.
  """
  @spec boss?(race()) :: boolean()
  def boss?(:boss), do: true
  def boss?(_), do: false

  # Private helper functions

  # Boss monsters typically have some damage reduction
  # This is a simplified version - in rAthena this varies by boss
  defp apply_boss_resistance do
    # TODO: Get actual boss resistance from mob data
    # For now, no special resistance
    1.0
  end

  # Future implementations for card/equipment systems:

  # defp calculate_card_modifier(weapon_cards, defender_race) do
  #   # Check weapon cards for race-specific damage bonuses
  #   # Example: Orc Skeleton Card gives +20% damage vs undead
  #   1.0
  # end

  # defp calculate_equipment_modifier(equipment, defender_race) do
  #   # Check armor/accessory racial damage bonuses
  #   1.0
  # end

  # defp calculate_skill_modifier(skills, defender_race) do
  #   # Check active skills that boost racial damage
  #   1.0
  # end
end
