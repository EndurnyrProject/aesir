defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection.Damage do
  @moduledoc """
  Resurrection's pure per-mode numbers for the offensive cast against a living
  undead enemy: the instant-death score, and the shape of the hit when the
  target survives that roll. All randomness is rolled by the caller.

  Renewal: the score is `10 * level + LUK + INT + base level + 300 - 300 * HP /
  max HP`, so the skill level barely moves it and a wounded target is far easier
  to destroy. A target that survives the roll takes the caster's magic attack
  scaled to `level` percent, which at four levels is a token hit.

  Pre-renewal: the score is `20 * level + LUK + INT + base level + 200 - 200 *
  HP / max HP`. The skill level counts double and the health term spans only two
  hundred points, so a high-level cast lands more often but a nearly dead target
  helps less. A target that survives the roll takes a flat `base level + INT +
  10 * level`, which ignores the caster's magic attack entirely.

  Both modes cap the score at 700 out of 1000.
  """

  alias Aesir.Commons.GameMode

  @typedoc "Caster and target amounts feeding the instant-death roll."
  @type score_inputs :: %{
          level: pos_integer(),
          luk: non_neg_integer(),
          int: non_neg_integer(),
          base_level: pos_integer(),
          target_hp: non_neg_integer(),
          target_max_hp: pos_integer()
        }

  @typedoc "Caster amounts feeding the surviving-target hit."
  @type hit_inputs :: %{level: pos_integer(), base_level: pos_integer(), int: non_neg_integer()}

  @score_cap 700

  @doc "Returns the out-of-1000 chance that the cast destroys the target outright."
  @spec instant_kill_score(GameMode.t(), score_inputs()) :: non_neg_integer()
  def instant_kill_score(:renewal, inputs), do: score(inputs, 10, 300)
  def instant_kill_score(:pre_renewal, inputs), do: score(inputs, 20, 200)

  @doc """
  Returns the magic-attack option fragment for a target that survives the roll:
  a percentage of the caster's magic attack in renewal, a flat amount that
  bypasses magic attack entirely in pre-renewal.
  """
  @spec undead_hit(GameMode.t(), hit_inputs()) :: keyword()
  def undead_hit(:renewal, %{level: level}), do: [skill_ratio: level]

  def undead_hit(:pre_renewal, %{level: level, base_level: base_level, int: int}),
    do: [skill_ratio: 0, bonus_matk: base_level + int + level * 10]

  @spec score(score_inputs(), pos_integer(), pos_integer()) :: non_neg_integer()
  defp score(inputs, level_weight, health_span) do
    (level_weight * inputs.level + inputs.luk + inputs.int + inputs.base_level + health_span -
       div(health_span * inputs.target_hp, inputs.target_max_hp))
    |> min(@score_cap)
  end
end
