defmodule Aesir.ZoneServer.Mmo.Combat.AtkPercent do
  @moduledoc """
  The status ATK percent of a weapon attack and the mastery-stacking predicate
  that gates it.

  The percent is `100` plus the `:atk_rate` status modifiers (Curse, Provoke, a
  stripped monster's weapon, Concentration, True Sight, a broken waist, Inc ATK
  Rate, Blood Lust, Fleet), capped to `0..65_535`. A player's skill that does
  not stack masteries takes `100`. Classic multiplies the skill-scaled damage by
  it; renewal starts the skill ratio from it; classic Earthquake scales its
  monster base by it.
  """

  alias Aesir.Commons.GameMode

  @spiral_pierce 397

  # Skills that take no mastery, refine, Star Crumb or spirit sphere bonus: Shield
  # Chain, Shield Boomerang, Acid Terror, Investigate, Asura Strike, Sacrifice,
  # both Dragon Breaths, Self Destruction, Shield Press, Earth Drive and the
  # monster Dragon Breath.
  @mastery_exempt_skills [480, 251, 230, 266, 271, 368, 2008, 5004, 2267, 2310, 2323, 731]

  @max 65_535

  @typedoc "The mastery bonus a skill is asked about."
  @type bonus :: :all | :refine | :star

  @typedoc "A unit's aggregated status modifiers."
  @type modifiers :: %{optional(atom()) => number()}

  @doc """
  Whether a skill takes the mastery block (`:all`: renewal's whole mastery ATK,
  classic's post-defense masteries and spirit spheres, and the ATK percent), the
  classic refine bonus or the classic Star Crumb bonus. Classic Spiral Pierce
  keeps only the refine and Star Crumb bonuses. A normal attack (`nil`) takes
  everything.
  """
  @spec stacks_masteries?(integer() | nil, bonus()) :: boolean()
  def stacks_masteries?(skill_id, _bonus) when skill_id in @mastery_exempt_skills, do: false

  def stacks_masteries?(@spiral_pierce, bonus),
    do: GameMode.mode() != :pre_renewal or bonus in [:refine, :star]

  def stacks_masteries?(_skill_id, _bonus), do: true

  @doc "The capped ATK percent of a unit's attack, `100` when nothing applies."
  @spec percent(atom(), integer() | nil, modifiers()) :: 0..65_535
  def percent(:player, skill_id, modifiers) do
    if stacks_masteries?(skill_id, :all), do: capped(modifiers), else: 100
  end

  def percent(_unit_type, _skill_id, modifiers), do: capped(modifiers)

  @doc "The percent as additive points over `100`, for the rate channels."
  @spec delta(atom(), integer() | nil, modifiers()) :: integer()
  def delta(unit_type, skill_id, modifiers), do: percent(unit_type, skill_id, modifiers) - 100

  defp capped(modifiers) do
    (100 + Map.get(modifiers, :atk_rate, 0)) |> max(0) |> min(@max)
  end
end
