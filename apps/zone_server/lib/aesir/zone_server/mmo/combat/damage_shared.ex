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
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @doc """
  Applies the defender's element resistance to `damage`.

  Reads the defender element (`{element, level}`, defaulting to `{:neutral, 1}`)
  and multiplies `damage` by `ElementModifiers.get_modifier/4` for the given
  `attack_element`. A defender whose `:element` is not an `{element, level}`
  tuple passes through unchanged.

  `attacker_modifiers` carries the attacker's status modifiers. An
  `{:element_ratio, element}` entry matching `attack_element` adds its
  percentage points to the element ratio — the seam through which the Sage
  element fields (Volcano, Deluge, Violent Gale) reach the damage pipeline,
  mirroring rAthena's src-side `battle_attr_fix` bonus (`battle.cpp:529-551`).
  """
  @spec apply_element(number(), ElementModifiers.element(), map(), map()) :: number()
  def apply_element(damage, attack_element, defender, attacker_modifiers \\ %{}) do
    case Map.get(defender, :element, {:neutral, 1}) do
      {defender_element, defender_level} ->
        ratio_bonus = Map.get(attacker_modifiers, {:element_ratio, attack_element}, 0)

        modifier =
          ElementModifiers.get_modifier(
            attack_element,
            defender_element,
            defender_level,
            ratio_bonus
          )

        damage * modifier

      _ ->
        damage
    end
  end

  @doc """
  Resolves an attacker combatant's aggregated status modifiers for the flat-
  damage element step.

  The flat BF_MISC path (`MiscDamageCalculator`) and the explicit-amount magic
  paths (`MagicAttack.execute_magic_damage/4` and fixed skill-unit hits) skip
  the full `DamageCalculator`/`MagicDamageCalculator` pipeline, so they never
  resolve the attacker's modifiers on their own. This is the seam that lets an
  `{:element_ratio, element}` bonus (the Sage element fields Volcano, Deluge and
  Violent Gale) reach those paths through `apply_element/4`.

  Returns `%{}` for an attacker without a resolvable unit (unowned traps,
  environmental damage), so `apply_element/4` simply finds no bonus.
  """
  @spec attacker_modifiers(map() | nil) :: map()
  def attacker_modifiers(%{unit_type: unit_type, unit_id: unit_id})
      when unit_type in [:player, :mob, :homunculus] and is_integer(unit_id) do
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  def attacker_modifiers(_attacker), do: %{}

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

  @doc """
  Rolls the per-hit weapon overrefine damage extra.

  Mirrors rAthena's `damage += rnd()%overrefine + 1` (`battle.cpp:2419`): a
  uniform integer in `1..band`. A `band` of `0` is a no-op.
  """
  @spec overrefine_roll(non_neg_integer()) :: non_neg_integer()
  def overrefine_roll(0), do: 0
  def overrefine_roll(band) when band > 0, do: roll(1, band + 1)

  @doc """
  Applies the rAthena Res/MRes soft-capped reduction curve to `damage`.

  Reduces `damage` by `res/(res+400) * 0.8`, so the reduction trends toward
  but never reaches 80% as `res` grows. A `res` of `0` (or below) is a no-op.
  """
  @spec res_reduction(number(), non_neg_integer()) :: number()
  def res_reduction(damage, res) when res > 0,
    do: damage - trunc(res / (res + 400) * 0.8 * damage)

  # ponytail: no ignore_res/ignore_mres pierce term yet -- every source is an
  # unmodeled 4th-job skill/status. Add the capped (50%) pierce when one
  # lands. rAthena battle.cpp:5603 / 6063.
  def res_reduction(damage, _res), do: damage
end
