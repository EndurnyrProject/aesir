defmodule Aesir.ZoneServer.Mmo.Combat.RaceModifiers do
  @moduledoc """
  Race-based combat modifiers based on the rAthena implementation.

  Currently covers the racial skill bonuses that have a live source of truth:
  Demon Bane (`demon_bane_atk/2`), Beast Bane (`beast_bane_atk/2`), Divine Protection
  (`divine_protection_def/2`), and Dragonology (`dragonology_atk_rate/2`,
  `dragonology_matk_rate/2`, `dragonology_resist_rate/2`), plus the race
  predicates. Shared race types and the mode-specific human-player race belong
  to `Aesir.ZoneServer.Mmo.Race`. Card and equipment race bonuses belong to the
  scripted item-bonus engine.
  """

  alias Aesir.ZoneServer.Mmo.Race

  @typedoc "A combatant's primary race."
  @type race :: Race.t()

  @brute_insect [:brute, :insect]

  @doc """
  Demon Bane (AL_DEMONBANE) additive physical ATK bonus.

  Returns the flat ATK added before defense when the defender counts as undead
  (undead defense element) or is demon race:
  `level * (base_level / 20.0 + 3.0)` truncated to an integer. The magnitude and
  the level term are the same in renewal and pre-renewal. The bonus never applies
  to a player defender. Returns `0` when the attacker has no Demon Bane level or
  the defender does not qualify.
  """
  @spec demon_bane_atk(map(), map()) :: non_neg_integer()
  def demon_bane_atk(%{demon_bane_level: level, progression: %{base_level: base_level}}, defender)
      when level > 0 do
    if undead_or_demon?(defender), do: trunc(level * (base_level / 20.0 + 3.0)), else: 0
  end

  def demon_bane_atk(_attacker, _defender), do: 0

  @doc """
  Beast Bane (HT_BEASTBANE) additive physical ATK bonus.

  Returns four ATK per learned level when the defender is Brute or Insect,
  otherwise zero.
  """
  @spec beast_bane_atk(map(), race()) :: non_neg_integer()
  def beast_bane_atk(%{beast_bane_level: level}, defender_race)
      when level > 0 and defender_race in @brute_insect,
      do: level * 4

  def beast_bane_atk(_attacker, _defender_race), do: 0

  @doc """
  Divine Protection (AL_DP) additive soft-DEF (VIT-DEF) bonus.

  Returns the flat soft defense added to the defender when the attacker counts
  as undead (undead defense element) or is demon race:
  `(base_level / 25.0 + 3.0) * level + 0.5` truncated to an integer. The
  magnitude and the level term are the same in renewal and pre-renewal. The bonus
  never applies against a player attacker. Returns `0` when the defender has no
  Divine Protection level or the attacker does not qualify.
  """
  @spec divine_protection_def(map(), map()) :: non_neg_integer()
  def divine_protection_def(
        %{divine_protection_level: level, progression: %{base_level: base_level}},
        attacker
      )
      when level > 0 do
    if undead_or_demon?(attacker), do: trunc((base_level / 25.0 + 3.0) * level + 0.5), else: 0
  end

  def divine_protection_def(_defender, _attacker), do: 0

  # Both passives are gated on a non-player opposing unit: neither works in PvP.
  @spec undead_or_demon?(map()) :: boolean()
  defp undead_or_demon?(%{unit_type: :player}), do: false

  defp undead_or_demon?(unit),
    do: Map.get(unit, :race) == :demon or undead_target?(unit)

  @doc """
  Dragonology (SA_DRAGONOLOGY) percentage physical ATK bonus vs Dragon-race
  targets: four percent per learned level. The source splits the bonus per
  wielding hand; Aesir does not split dual-wield hands, so both collapse into
  this one rate. Returns `0` when the attacker has no Dragonology level or the
  target is not Dragon race.
  """
  @spec dragonology_atk_rate(map(), race()) :: non_neg_integer()
  def dragonology_atk_rate(%{dragonology_level: level}, :dragon) when level > 0, do: level * 4
  def dragonology_atk_rate(_attacker, _defender_race), do: 0

  @doc """
  Dragonology percentage MATK bonus vs Dragon-race targets: two percent per
  learned level. Returns `0` when the attacker has no Dragonology level or the
  target is not Dragon race.
  """
  @spec dragonology_matk_rate(map(), race()) :: non_neg_integer()
  def dragonology_matk_rate(%{dragonology_level: level}, :dragon) when level > 0, do: level * 2
  def dragonology_matk_rate(_attacker, _defender_race), do: 0

  @doc """
  Dragonology percentage damage-taken reduction from Dragon-race attackers: four
  percent per learned level. The per-race damage-taken reduction is shared by the
  physical and magic pipelines, so this rate applies uniformly to both. Returns
  `0` when the defender has no Dragonology level or the attacker is not Dragon
  race.
  """
  @spec dragonology_resist_rate(map(), race()) :: non_neg_integer()
  def dragonology_resist_rate(%{dragonology_level: level}, :dragon) when level > 0,
    do: level * 4

  def dragonology_resist_rate(_defender, _attacker_race), do: 0

  @doc """
  Gets the player race for the active game mode.
  """
  @spec player_race() :: :player_human | :demi_human
  defdelegate player_race(), to: Race

  @doc """
  Checks if a race is considered undead.
  Useful for special mechanics that affect undead differently.
  """
  @spec undead?(race()) :: boolean()
  def undead?(:undead), do: true
  def undead?(_), do: false

  @doc """
  Whether a unit counts as undead for the skills and passives that single undead
  out.

  Detection is by **defense element only**, which is the default the source ships
  with: a unit whose defense element is undead qualifies whatever its race, and
  the undead race on its own does not. `undead?/1` remains the plain race test
  for callers that genuinely mean the race.
  """
  @spec undead_target?(map()) :: boolean()
  def undead_target?(unit), do: undead_element?(Map.get(unit, :element))

  @spec undead_element?(term()) :: boolean()
  defp undead_element?(element), do: element == :undead or match?({:undead, _level}, element)

  @doc """
  Checks the `:boss` classification label for compatibility with existing callers.
  Boss classification is independent of a unit's race.
  """
  @spec boss?(atom()) :: boolean()
  def boss?(:boss), do: true
  def boss?(_), do: false
end
