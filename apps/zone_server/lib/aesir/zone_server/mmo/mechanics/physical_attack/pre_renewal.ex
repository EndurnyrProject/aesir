defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal do
  @moduledoc """
  Classic player weapon bounds and post-defense refine/mastery arithmetic.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.PreRenewal, as: Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack

  @behaviour PhysicalAttack

  @impl true
  @spec calculate(PhysicalAttack.parts(), PhysicalAttack.context()) :: integer()
  def calculate(parts, context) do
    weapon = div((parts.weapon_atk + Map.get(context, :weapon_bonus, 0)) * context.size_rate, 100)

    base =
      parts.status_atk + parts.flat_atk + weapon + parts.overrefine_atk +
        Map.get(context, :flat_bonus, 0)

    base = critical_bonus(base, context)
    base = if parts.source == :shield, do: defend(base, context), else: base

    skilled =
      div(base * Map.get(context, :skill_ratio, 100), 100) + Map.get(context, :bonus_atk, 0)

    skilled =
      skilled
      |> PhysicalAttack.rate(Map.get(context, :skill_atk_rate, 0))
      |> PhysicalAttack.rate(-Map.get(context, :skill_taken_rate, 0))
      |> PhysicalAttack.status_damage(context)

    defended = if parts.source == :shield, do: skilled, else: defend(skilled, context)
    mastered = max(defended + parts.refine_atk, 1) + parts.mastery_atk

    rates =
      Map.update!(
        context.attacker_rates,
        :race_class,
        &(&1 + Map.get(context, :global_race_rate, 0))
      )

    mastered
    |> Kernel.*(context.weapon_element)
    |> trunc()
    |> PhysicalAttack.attacker_cardfix(rates)
    |> PhysicalAttack.range_damage(context)
    |> PhysicalAttack.defender_cardfix(Map.get(context, :defender_rates), :weapon)
    |> PhysicalAttack.finish(context)
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
