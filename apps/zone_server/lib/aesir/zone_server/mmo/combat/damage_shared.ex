defmodule Aesir.ZoneServer.Mmo.Combat.DamageShared do
  @moduledoc """
  Type-agnostic damage tail shared by the physical and magic calculators.

  Pulls the element-resistance step, the generic `damage_multiplier`, and the
  min-1 clamp out of the per-type calculators so both the physical
  `DamageCalculator` and the magic calculator apply them identically.

  Type-specific steps (physical `atk_bonus`/`damage_bonus` additive, weapon
  attack, MATK build) stay in their respective calculators.
  """

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers

  @doc """
  Applies the defender's element resistance to `damage`.

  Reads the defender element (`{element, level}`, defaulting to `{:neutral, 1}`)
  and multiplies `damage` by `ElementModifiers.get_modifier/3` for the given
  `attack_element`. A defender whose `:element` is not an `{element, level}`
  tuple passes through unchanged.
  """
  @spec apply_element(number(), ElementModifiers.element(), map()) :: number()
  def apply_element(damage, attack_element, defender) do
    case Map.get(defender, :element, {:neutral, 1}) do
      {defender_element, defender_level} ->
        modifier = ElementModifiers.get_modifier(attack_element, defender_element, defender_level)
        damage * modifier

      _ ->
        damage
    end
  end

  @doc """
  Applies the generic status-effect `damage_multiplier` to `damage`.

  Multiplies by `1.0 + damage_multiplier`, defaulting the multiplier to `0.0`
  when absent.
  """
  @spec apply_damage_multiplier(number(), map()) :: number()
  def apply_damage_multiplier(damage, modifiers) do
    damage * (1.0 + Map.get(modifiers, :damage_multiplier, 0.0))
  end

  @doc """
  Clamps a damage value to a minimum of 1 and truncates to an integer.
  """
  @spec clamp_min_one(number()) :: pos_integer()
  def clamp_min_one(value) do
    max(1, trunc(value))
  end

  @doc """
  Rolls an integer in the half-open range `[min, max)`.

  Mirrors rAthena's `min + rnd()%(max-min)` shape (upper bound exclusive), so
  the result is `min` when `max <= min` and otherwise lands in `[min, max - 1]`.
  """
  @spec roll(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def roll(min, max) when max > min, do: min + (:rand.uniform(max - min) - 1)
  def roll(min, _max), do: min
end
