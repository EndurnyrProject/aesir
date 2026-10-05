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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @doc """
  Runs one attribute step on an integer `damage`, the reference `battle_attr_fix`.

  Reads the defender's `{element, level}` (default `{:neutral, 1}`); a defender
  without an element tuple passes `damage` through. The step captures, in order,
  the attacker's matching element field (`{:element_ratio, element}`: Volcano,
  Deluge, Violent Gale) and, for fire against a webbed player, mob or Homunculus,
  the web bonus. A webbed holder loses its shortest web in this step, so every
  attribute step is an actual application: never call this to preview damage.

  Options:

    * `:attacker_modifiers` - the attacker's status modifiers when already resolved;
      otherwise they are read for `attacker`.
    * `:allow_negative` - lets a negative final ratio through (the weapon
      post-defense step); otherwise a negative ratio deals 0.
  """
  @spec apply_element_step(
          integer(),
          ElementModifiers.element(),
          map() | nil,
          map(),
          keyword()
        ) :: integer()
  def apply_element_step(damage, attack_element, attacker, defender, opts \\ []) do
    case Map.get(defender, :element, {:neutral, 1}) do
      {defense_element, defense_level} ->
        modifiers =
          Keyword.get_lazy(opts, :attacker_modifiers, fn -> attacker_modifiers(attacker) end)

        ElementModifiers.adjust_damage(damage, %{
          attack_element: attack_element,
          defense_element: defense_element,
          defense_level: defense_level,
          modifiers:
            field_modifier(modifiers, attack_element) ++ web_modifier(attack_element, defender),
          allow_negative_ratio?: Keyword.get(opts, :allow_negative, false)
        })

      _no_element ->
        damage
    end
  end

  defp field_modifier(modifiers, attack_element) do
    case Map.get(modifiers, {:element_ratio, attack_element}, 0) do
      0 -> []
      points -> [{:field, points}]
    end
  end

  defp web_modifier(:fire, %{unit_type: type, unit_id: id})
       when type in [:player, :mob, :homunculus] do
    if SpiderWeb.consume(type, id), do: [{:spider_web, 100}], else: []
  end

  defp web_modifier(_element, _defender), do: []

  @doc """
  Resolves an attacker combatant's aggregated status modifiers for the flat-
  damage element step.

  The flat BF_MISC path (`MiscDamageCalculator`) and the explicit-amount magic
  paths (`MagicAttack.execute_magic_damage/4` and fixed skill-unit hits) skip
  the full `DamageCalculator`/`MagicDamageCalculator` pipeline, so they never
  resolve the attacker's modifiers on their own. This is the seam that lets an
  `{:element_ratio, element}` bonus (the Sage element fields Volcano, Deluge and
  Violent Gale) reach those paths through `apply_element_step/5`.

  Returns `%{}` for an attacker without a resolvable unit (unowned traps,
  environmental damage), so `apply_element_step/5` simply finds no bonus.
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
