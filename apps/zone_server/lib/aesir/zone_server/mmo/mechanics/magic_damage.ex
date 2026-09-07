defmodule Aesir.ZoneServer.Mmo.Mechanics.MagicDamage do
  @moduledoc "Contract for ordinary magic arithmetic over one rolled MATK and captured inputs."

  @typedoc "Independent attacker card channels, including secondary monster groups."
  @type attack_rates :: %{
          size: integer(),
          race2: integer(),
          element_target: integer(),
          atk_ele: integer(),
          race: integer(),
          class: integer()
        }

  @typedoc "Independent defender card channels; positive rates reduce damage."
  @type defense_rates :: %{
          element: integer(),
          size: integer(),
          race2: integer(),
          race: integer(),
          class: integer(),
          magic: integer()
        }

  @typedoc "Numeric inputs captured by the magic damage coordinator."
  @type context :: %{
          hard_mdef: integer(),
          soft_mdef: integer(),
          ignore_mdef_rate: integer(),
          ignore_mdef?: boolean(),
          element_modifier: number(),
          skill_ratio: integer(),
          bonus_matk: integer(),
          smatk: integer(),
          mres: integer(),
          matk_rate: integer(),
          damage_multiplier: number(),
          skill_atk_rate: integer(),
          skill_taken_rate: integer(),
          attack: attack_rates(),
          taken: defense_rates()
        }

  @doc "Calculates an ordinary magic hit without lookups or random draws."
  @callback calculate(integer(), context()) :: pos_integer()

  @doc "Applies the skill ratio, post-ratio flat addition and shared status channels."
  @spec skill_damage(integer(), context()) :: integer()
  def skill_damage(matk, context) do
    skilled = div(matk * context.skill_ratio, 100) + context.bonus_matk
    rated = div(skilled * (100 + context.matk_rate), 100)
    trunc(rated * (1 + context.damage_multiplier))
  end

  @doc "Adds a skill's percentage delta with truncation of the changed amount."
  @spec skill_rate(integer(), integer()) :: integer()
  def skill_rate(damage, rate), do: damage + div(damage * rate, 100)

  @doc "Applies the ordered defender card factor without merging resistance channels."
  @spec defender_cardfix(integer(), defense_rates()) :: integer()
  def defender_cardfix(damage, rates) do
    factor =
      1000
      |> factor(-rates.element)
      |> factor(-rates.size)
      |> factor(-rates.race2)
      |> factor(-rates.race)
      |> factor(-rates.class)
      |> factor(-min(max(rates.magic, 0), 100))

    apply_factor(damage, factor)
  end

  @doc "Accumulates a percentage channel into a per-mille card factor."
  @spec factor(integer(), integer()) :: integer()
  def factor(factor, rate), do: div(factor * (100 + rate), 100)

  @doc "Applies a card factor, truncating the removed or added amount."
  @spec apply_factor(integer(), integer()) :: integer()
  def apply_factor(damage, factor), do: damage - div(damage * (1000 - max(0, factor)), 1000)
end
