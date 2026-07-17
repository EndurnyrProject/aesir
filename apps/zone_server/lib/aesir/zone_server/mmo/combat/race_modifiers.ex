defmodule Aesir.ZoneServer.Mmo.Combat.RaceModifiers do
  @moduledoc """
  Race-based combat modifiers based on the rAthena implementation.

  Currently covers the racial skill bonuses that have a live source of truth:
  Demon Bane (`demon_bane_atk/2`), Divine Protection
  (`divine_protection_def/2`), and Dragonology (`dragonology_atk_rate/2`,
  `dragonology_matk_rate/2`, `dragonology_resist_rate/2`), plus the race
  taxonomy and predicates. Card / equipment race bonuses (`bonus2 bAddRace, ...`)
  belong to the scripted item-bonus engine, which does not exist yet.

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
  Dragonology (SA_DRAGONOLOGY) percentage physical ATK bonus vs Dragon-race
  targets, matching renewal rAthena `status_calc_pc_additional`
  (`status.cpp:4682-4700`): `level * 4` added to `right_weapon.addrace[RC_DRAGON]`
  (and `left_weapon.addrace[RC_DRAGON]` when `!battle_config.left_cardfix_to_right`
  — Aesir does not split dual-wield hands, so both collapse into this one rate).
  Returns `0` when the attacker has no Dragonology level or the target is not
  Dragon race.
  """
  @spec dragonology_atk_rate(map(), race()) :: non_neg_integer()
  def dragonology_atk_rate(%{dragonology_level: level}, :dragon) when level > 0, do: level * 4
  def dragonology_atk_rate(_attacker, _defender_race), do: 0

  @doc """
  Dragonology percentage MATK bonus vs Dragon-race targets
  (`indexed_bonus.magic_addrace[RC_DRAGON]`, `level * 2`,
  `status.cpp:4682-4700`). Returns `0` when the attacker has no Dragonology
  level or the target is not Dragon race.
  """
  @spec dragonology_matk_rate(map(), race()) :: non_neg_integer()
  def dragonology_matk_rate(%{dragonology_level: level}, :dragon) when level > 0, do: level * 2
  def dragonology_matk_rate(_attacker, _defender_race), do: 0

  @doc """
  Dragonology percentage damage-taken reduction from Dragon-race attackers
  (`indexed_bonus.subrace[RC_DRAGON]`, `level * 4`, `status.cpp:4682-4700`).
  rAthena's `subrace` cardfix (`battle_calc_damage`) is shared by the physical
  and magic pipelines, so this rate applies uniformly to both. Returns `0`
  when the defender has no Dragonology level or the attacker is not Dragon
  race.
  """
  @spec dragonology_resist_rate(map(), race()) :: non_neg_integer()
  def dragonology_resist_rate(%{dragonology_level: level}, :dragon) when level > 0,
    do: level * 4

  def dragonology_resist_rate(_defender, _attacker_race), do: 0

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
end
