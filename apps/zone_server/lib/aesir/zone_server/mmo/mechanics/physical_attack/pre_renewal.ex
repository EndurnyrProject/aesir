defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal do
  @moduledoc """
  Classic player weapon bounds and post-defense refine/mastery arithmetic.

  A hit is split at its single post-defense attribute step, which the
  coordinator owns: `pre_element/2` runs the base, skill ratio, defense, refine
  and mastery stages; `post_element/2` runs the cards and final reduction.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.PreRenewal, as: Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack

  @behaviour PhysicalAttack

  @doc """
  Returns the hand's normal-attack base damage with its refine bonus, the base of
  Magnum Break's fire share (`wd->basedamage`).
  """
  @spec normal_base(PhysicalAttack.parts(), PhysicalAttack.context()) :: integer()
  def normal_base(parts, context), do: base(parts, context) + parts.refine_atk

  @doc "Calculates one classic hit up to its post-defense attribute step."
  @spec pre_element(PhysicalAttack.parts(), PhysicalAttack.context()) :: integer()
  def pre_element(parts, context) do
    base = critical_bonus(base(parts, context), context)
    base = if parts.source == :shield, do: defend(base, context), else: base

    skilled =
      div(base * Map.get(context, :skill_ratio, 100), 100) + Map.get(context, :bonus_atk, 0)

    skilled =
      skilled
      |> PhysicalAttack.rate(Map.get(context, :skill_atk_rate, 0))
      |> PhysicalAttack.rate(-Map.get(context, :skill_taken_rate, 0))
      |> PhysicalAttack.status_damage(context)

    defended = if parts.source == :shield, do: skilled, else: defend(skilled, context)

    max(trunc(defended) + parts.refine_atk, 1) + parts.mastery_atk +
      Map.get(context, :post_defense_atk, 0)
  end

  @doc "Finishes one classic hit after its attribute step: cards and final reduction."
  @spec post_element(integer(), PhysicalAttack.context()) :: integer()
  def post_element(damage, context) do
    rates =
      Map.update!(
        context.attacker_rates,
        :race_class,
        &(&1 + Map.get(context, :global_race_rate, 0))
      )

    damage
    |> PhysicalAttack.attacker_cardfix(rates)
    |> PhysicalAttack.range_damage(context)
    |> PhysicalAttack.defender_cardfix(Map.get(context, :defender_rates), :weapon)
    |> PhysicalAttack.finish(context)
  end

  defp base(parts, context) do
    weapon = div((parts.weapon_atk + Map.get(context, :weapon_bonus, 0)) * context.size_rate, 100)

    parts.status_atk + parts.flat_atk + weapon + parts.overrefine_atk +
      Map.get(context, :flat_bonus, 0)
  end

  defp critical_bonus(damage, %{critical?: true} = context) do
    PhysicalAttack.rate(damage, max(Map.get(context, :crit_atk_rate, 0), 0))
  end

  defp critical_bonus(damage, _context), do: damage

  defp defend(damage, %{critical?: true}), do: damage
  defp defend(damage, context), do: PhysicalAttack.apply_defense(damage, context, Defense)

  @impl true
  @spec base_attack(PhysicalAttack.parts()) :: integer()
  def base_attack(parts) do
    parts.status_atk + parts.flat_atk + parts.weapon_atk + parts.refine_atk +
      parts.overrefine_atk + parts.mastery_atk
  end

  @impl true
  @spec weapon_bounds(PhysicalAttack.weapon_inputs()) :: {non_neg_integer(), non_neg_integer()}
  def weapon_bounds(inputs) do
    maximum = inputs.base_atk
    minimum = min(div(max(inputs.dex, 0) * (80 + 20 * inputs.weapon_level), 100), maximum)
    minimum = if inputs.arrow?, do: div(minimum * maximum, 100), else: minimum
    maximum = max(minimum, maximum)

    if inputs.critical? or inputs.max_weapon_damage?,
      do: {maximum, maximum},
      else: {minimum, max(minimum, maximum - 1)}
  end
end
