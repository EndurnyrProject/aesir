defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.Renewal do
  @moduledoc """
  Renewal player weapon bounds and component-based physical damage.
  """

  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.Renewal, as: Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack

  @behaviour PhysicalAttack

  @impl true
  @spec calculate(PhysicalAttack.parts(), PhysicalAttack.context()) :: integer()
  def calculate(parts, context) do
    multiplier = if parts.hand == :right_hand and parts.source == :weapon, do: 2, else: 1
    status = trunc(parts.status_atk * context.neutral_element) * multiplier
    weapon = parts.weapon_atk + parts.overrefine_atk + Map.get(context, :weapon_bonus, 0)
    weapon = trunc(div(weapon * context.size_rate, 100) * context.weapon_element)

    equipment =
      trunc((parts.flat_atk + Map.get(context, :flat_bonus, 0)) * context.weapon_element)

    percent_atk = div((weapon + equipment) * Map.get(context, :equipment_atk_rate, 0), 100)
    status = modified_component(status, context, :status)
    mastery = modified_component(parts.mastery_atk, context, :status)
    weapon = modified_component(weapon, context, :weapon)
    equipment = modified_component(equipment, context, :weapon)
    percent_atk = PhysicalAttack.status_damage(percent_atk, context)

    core =
      PhysicalAttack.rate(status + weapon + equipment + percent_atk, Map.get(context, :patk, 0))

    attack =
      (core + mastery)
      |> critical_equipment_bonus(context)
      |> PhysicalAttack.range_damage(context)

    skilled =
      div(attack * Map.get(context, :skill_ratio, 100), 100) +
        Map.get(context, :bonus_atk, 0)

    skilled
    |> reduce_res(context)
    |> PhysicalAttack.apply_defense(context, Defense)
    |> trunc()
    |> PhysicalAttack.rate(Map.get(context, :skill_atk_rate, 0))
    |> PhysicalAttack.rate(-Map.get(context, :skill_taken_rate, 0))
    |> max(1)
    |> critical_damage(context)
    |> PhysicalAttack.finish(context)
  end

  defp reduce_res(damage, %{defense_mode: :simple}), do: damage

  defp reduce_res(damage, context),
    do: DamageShared.res_reduction(damage, Map.get(context, :res, 0))

  defp modified_component(damage, context, channel) do
    damage
    |> attacker_component(context, channel)
    |> PhysicalAttack.defender_cardfix(Map.get(context, :defender_rates), channel)
    |> PhysicalAttack.status_damage(context)
  end

  defp attacker_component(damage, context, :status) do
    PhysicalAttack.rate(damage, Map.get(context, :global_race_rate, 0))
  end

  defp attacker_component(damage, context, :weapon) do
    rates =
      Map.update!(
        context.attacker_rates,
        :race_class,
        &(&1 + Map.get(context, :global_race_rate, 0))
      )

    PhysicalAttack.attacker_cardfix(damage, rates)
  end

  defp critical_equipment_bonus(damage, %{critical?: true} = context) do
    divisor = if Map.get(context, :skill_id), do: 200, else: 100
    damage + div(damage * Map.get(context, :crit_atk_rate, 0), divisor)
  end

  defp critical_equipment_bonus(damage, _context), do: damage

  defp critical_damage(damage, %{critical?: true} = context) do
    CriticalHits.apply_critical_damage(damage, %{
      combat_stats: %{crate: Map.get(context, :crate, 0)}
    })
  end

  defp critical_damage(damage, _context), do: damage

  @impl true
  @spec base_attack(PhysicalAttack.parts()) :: integer()
  def base_attack(parts) do
    status_multiplier = if parts.hand == :right_hand and parts.source == :weapon, do: 2, else: 1

    parts.status_atk * status_multiplier + parts.flat_atk + parts.weapon_atk +
      parts.overrefine_atk + parts.mastery_atk
  end

  @impl true
  @spec weapon_bounds(PhysicalAttack.weapon_inputs()) :: {non_neg_integer(), non_neg_integer()}
  def weapon_bounds(inputs) do
    base = inputs.base_atk
    center = 200 * (base + inputs.refine_atk) + base * inputs.primary_stat
    variance = 10 * base * inputs.weapon_level
    minimum = max(div(center - variance, 200), 0)
    maximum = min(div(center + variance, 200), 65_535)

    if inputs.critical? or inputs.max_weapon_damage?,
      do: {maximum, maximum},
      else: {minimum, maximum}
  end
end
