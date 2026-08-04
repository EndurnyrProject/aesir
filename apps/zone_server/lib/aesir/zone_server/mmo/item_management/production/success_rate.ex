defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.SuccessRate do
  @moduledoc """
  Calculates deterministic Renewal production chances in hundredths of a percent.

  Random terms are supplied by the caller; `pharmacy_roll/2` derives one from a
  caller-injected rng, and this module never touches the rng backend directly.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned

  @production_rate_multiplier 1
  @maximum_rate 10_000

  @typedoc "Function that returns an integer from 1 through its upper bound."
  @type pharmacy_rng :: (pos_integer() -> pos_integer())

  @typedoc "Inputs for the pharmacy formula."
  @type pharmacy_params :: %{
          required(:job_level) => non_neg_integer(),
          required(:int) => non_neg_integer(),
          required(:dex) => non_neg_integer(),
          required(:luk) => non_neg_integer(),
          required(:skill_level) => non_neg_integer(),
          required(:learned_skills) => Learned.t(),
          required(:instruction_change_rank) => non_neg_integer(),
          required(:random_term) => integer()
        }

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
  Rolls the formula term for a pharmacy product's class.
  """
  @spec pharmacy_roll(integer(), pharmacy_rng()) :: integer()
  def pharmacy_roll(product_id, rng) when is_function(rng, 1) do
    case product_class_range(product_id) do
      nil -> 0
      range -> range.first + rng.(Range.size(range)) - 1
    end
  end

  @doc """
  Calculates a pharmacy chance and clamps it to `1..10_000`.
  """
  @spec pharmacy(integer(), pharmacy_params() | map()) :: pos_integer()
  def pharmacy(product_id, %{
        job_level: job_level,
        int: int,
        dex: dex,
        luk: luk,
        skill_level: skill_level,
        learned_skills: learned_skills,
        instruction_change_rank: instruction_change_rank,
        random_term: random_term
      })
      when is_integer(instruction_change_rank) and instruction_change_rank >= 0 do
    rate =
      50 * learning_potion_level(learned_skills) +
        300 * skill_level +
        20 * job_level +
        10 * div(int, 2) +
        10 * dex +
        10 * luk +
        100 * instruction_change_rank +
        product_class_roll(product_id, random_term)

    rate
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

  defp learning_potion_level(learned_skills) do
    case Catalog.by_name(:am_learningpotion) do
      {:ok, %{id: id}} -> Learned.learned_level(learned_skills, id)
      :error -> 0
    end
  end

  defp product_class_roll(product_id, random_term) do
    if is_nil(product_class_range(product_id)), do: 0, else: random_term
  end

  defp product_class_range(product_id) when product_id in 501..504, do: 2010..3000
  defp product_class_range(970), do: 1010..2000
  defp product_class_range(product_id) when product_id in 7135..7138, do: 10..1000
  defp product_class_range(547), do: -500..-10
  defp product_class_range(product_id) when product_id in [12_428, 7139], do: -1000..-10
  defp product_class_range(_product_id), do: nil

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
