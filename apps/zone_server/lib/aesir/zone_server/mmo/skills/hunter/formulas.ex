defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.Formulas do
  @moduledoc """
  Deterministic calculations shared by Hunter skills.
  """

  @spec blitz_beat_base_damage(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  def blitz_beat_base_damage(blitz_level, steel_crow_level, agi, dex) do
    20 * blitz_level + 6 * steel_crow_level + 2 * div(agi, 2) + 2 * div(dex, 10)
  end

  @doc "Returns the inclusive threshold for a random roll in 0..999, used as `roll <= threshold`."
  @spec auto_blitz_chance(non_neg_integer()) :: pos_integer()
  def auto_blitz_chance(luk), do: div(luk * 10, 3) + 1

  @spec auto_blitz_effective_level(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def auto_blitz_effective_level(learned_level, job_level) do
    min(learned_level, div(job_level + 9, 10))
  end
end
