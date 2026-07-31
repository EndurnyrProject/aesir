defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.SuccessRate do
  @moduledoc """
  Calculates deterministic Renewal production chances in hundredths of a percent.

  Random terms are supplied by the caller; this module never rolls them.
  """

  @production_rate_multiplier 1
  @maximum_rate 10_000

  @typedoc "Inputs shared by mineral-refining formulas."
  @type mineral_params :: %{
          required(:job_level) => non_neg_integer(),
          required(:dex) => non_neg_integer(),
          required(:luk) => non_neg_integer(),
          required(:random_term) => non_neg_integer(),
          required(:skill_level) => non_neg_integer()
        }

  @typedoc "A mineral-refining recipe category."
  @type mineral_kind :: :iron | :steel | :elemental_stone | :star_crumb

  @typedoc "Inputs for the weapon-forging formula."
  @type weapon_params :: %{
          required(:job_level) => non_neg_integer(),
          required(:dex) => non_neg_integer(),
          required(:luk) => non_neg_integer(),
          required(:random_term) => non_neg_integer(),
          required(:tier) => 1..3,
          required(:family_skill_level) => non_neg_integer(),
          required(:weapon_research_level) => non_neg_integer(),
          required(:oridecon_research_level) => non_neg_integer(),
          required(:crumb_count) => non_neg_integer(),
          required(:elemental_stone?) => boolean(),
          required(:anvil_bonus) => non_neg_integer()
        }

  @doc """
  Calculates a weapon-forging chance and clamps it to `1..10_000`.
  """
  @spec weapon(weapon_params()) :: pos_integer()
  def weapon(%{
        job_level: job_level,
        dex: dex,
        luk: luk,
        random_term: random_term,
        tier: tier,
        family_skill_level: family_skill_level,
        weapon_research_level: weapon_research_level,
        oridecon_research_level: oridecon_research_level,
        crumb_count: crumb_count,
        elemental_stone?: elemental_stone?,
        anvil_bonus: anvil_bonus
      }) do
    rate =
      base(job_level, dex, luk, random_term) +
        tier_bonus(tier) +
        500 * family_skill_level +
        100 * weapon_research_level +
        oridecon_research_bonus(tier, oridecon_research_level) -
        elemental_stone_penalty(elemental_stone?) -
        1500 * crumb_count +
        anvil_bonus

    rate
    |> Kernel.*(@production_rate_multiplier)
    |> max(1)
    |> min(@maximum_rate)
  end

  @doc """
  Calculates a mineral-refining chance without the weapon multiplier or floor.

  Star Crumb refining is guaranteed and ignores the supplied formula inputs.
  """
  @spec mineral(mineral_kind(), mineral_params() | map()) :: integer()
  def mineral(:star_crumb, _params), do: @maximum_rate

  def mineral(kind, %{
        job_level: job_level,
        dex: dex,
        luk: luk,
        random_term: random_term,
        skill_level: skill_level
      }) do
    base(job_level, dex, luk, random_term) + mineral_bonus(kind) + 500 * skill_level
  end

  defp base(job_level, dex, luk, random_term) do
    20 * job_level + 10 * dex + 10 * luk + random_term
  end

  defp tier_bonus(1), do: 4000
  defp tier_bonus(2), do: 2000
  defp tier_bonus(3), do: 1000

  defp oridecon_research_bonus(3, level), do: 100 * level
  defp oridecon_research_bonus(tier, _level) when tier in [1, 2], do: 0

  defp elemental_stone_penalty(true), do: 2500
  defp elemental_stone_penalty(false), do: 0

  defp mineral_bonus(:iron), do: 4000
  defp mineral_bonus(:steel), do: 3000
  defp mineral_bonus(:elemental_stone), do: 1000
end
