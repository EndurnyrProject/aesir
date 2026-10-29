defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.Renewal do
  @moduledoc """
  Renewal player weapon bounds and component-based physical damage.

  A hit runs in fixed stages so the coordinator can own every attribute step
  between them: `prepare_components/2` sizes the weapon component, the
  coordinator runs the component attribute steps (status, weapon and equipment
  of both hands, in the reference order) and doubles right-hand status ATK,
  `after_component_elements/2` derives the equipment percentage part and then
  adds Stave Crasher's rolled MATK (`:stave_matk`) to the weapon component,
  `calculate_components/2` runs component cards, the critical or signed
  non-critical equipment bonus, the skill ratio (started from the ATK percent,
  with the status ratio adds), Advanced Katar Mastery's rate (`:katar_atk_rate`)
  and defense, and
  `finish_attack/2` runs the critical tail after any post-defense attribute step.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Critical
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.Renewal, as: Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack

  @behaviour PhysicalAttack

  @typedoc "One hand's attack components between the renewal stages."
  @type components :: %{
          status_atk: integer(),
          weapon_atk: integer(),
          flat_atk: integer(),
          mastery_atk: integer(),
          percent_atk: integer(),
          hand: :right_hand | :left_hand,
          source: :weapon | :shield
        }

  @doc """
  Prepares one hand's components before their attribute steps: the weapon
  component is sized, and status, equipment and mastery ATK are raw.
  """
  @spec prepare_components(PhysicalAttack.parts(), PhysicalAttack.context()) :: components()
  def prepare_components(parts, context) do
    weapon = parts.weapon_atk + parts.overrefine_atk

    %{
      status_atk: parts.status_atk,
      weapon_atk: div(weapon * context.size_rate, 100),
      flat_atk: parts.flat_atk + Map.get(context, :flat_bonus, 0),
      mastery_atk: parts.mastery_atk,
      percent_atk: 0,
      hand: parts.hand,
      source: parts.source
    }
  end

  @doc """
  Derives the equipment percentage part from the attribute-adjusted weapon and
  equipment components, then adds Stave Crasher's rolled MATK to the weapon
  component. The MATK takes neither the weapon's size and attribute steps nor a
  share of the percentage part, but does take the later weapon cards.
  """
  @spec after_component_elements(components(), PhysicalAttack.context()) :: components()
  def after_component_elements(components, context) do
    percent =
      div(
        (components.weapon_atk + components.flat_atk) * Map.get(context, :equipment_atk_rate, 0),
        100
      )

    %{
      components
      | percent_atk: percent,
        weapon_atk: components.weapon_atk + Map.get(context, :stave_matk, 0)
    }
  end

  @doc """
  Runs component cards, the summation, the skill ratio and defense, ending at the
  reference post-defense minimum of 1.
  """
  @spec calculate_components(components(), PhysicalAttack.context()) :: integer()
  def calculate_components(components, context) do
    status = modified_component(components.status_atk, context, :status)
    mastery = modified_component(components.mastery_atk, context, :status)

    weapon =
      components.weapon_atk |> modified_component(context, :weapon) |> edp_component(context)

    equipment =
      components.flat_atk |> modified_component(context, :weapon) |> edp_component(context)

    percent_atk = PhysicalAttack.damage_multiplier(components.percent_atk, context)

    core =
      PhysicalAttack.rate(status + weapon + equipment + percent_atk, Map.get(context, :patk, 0))

    attack =
      (div(core * Map.get(context, :base_atk_rate, 100), 100) + mastery)
      |> critical_equipment_bonus(context)
      |> PhysicalAttack.range_damage(context)

    skilled =
      div(attack * (PhysicalAttack.skill_ratio(context) + Map.get(context, :atk_rate, 0)), 100) +
        Map.get(context, :bonus_atk, 0)

    skilled
    |> PhysicalAttack.add_rate(Map.get(context, :katar_atk_rate, 0))
    |> reduce_res(context)
    |> PhysicalAttack.apply_defense(context, Defense)
    |> trunc()
    |> Kernel.+(Map.get(context, :post_defense_atk, 0))
    |> PhysicalAttack.add_rate(Map.get(context, :skill_atk_rate, 0))
    |> PhysicalAttack.add_rate(-Map.get(context, :skill_taken_rate, 0))
    |> max(1)
  end

  @doc """
  Runs the critical tail after any post-defense attribute step: the critical
  multiplier, then the target's equipment critical reduction (`:crit_def_rate`).
  """
  @spec finish_attack(integer(), PhysicalAttack.context()) :: integer()
  def finish_attack(damage, context), do: critical_damage(damage, context)

  defp edp_component(damage, %{edp_level: level} = context) when level > 0 do
    if Map.get(context, :skill_id) in [149, 141, 406, 137, 1004],
      do: damage,
      else: div(damage * (250 + 30 * level), 100)
  end

  defp edp_component(damage, _context), do: damage

  defp reduce_res(damage, %{defense_mode: :simple}), do: damage

  defp reduce_res(damage, context),
    do: DamageShared.res_reduction(damage, Map.get(context, :res, 0))

  # The attacker's cards scale only the weapon and equipment components; the
  # target's scale every component, its element resists only the weapon ones.
  defp modified_component(damage, context, channel) do
    damage
    |> attacker_component(context, channel)
    |> PhysicalAttack.defender_cardfix(defender_cards(Map.get(context, :defender_cards), channel))
    |> PhysicalAttack.damage_multiplier(context)
  end

  defp attacker_component(damage, _context, :status), do: damage

  defp attacker_component(damage, context, :weapon),
    do: PhysicalAttack.attacker_cardfix(damage, context.attacker_cards)

  defp defender_cards(nil, _channel), do: nil
  defp defender_cards(cards, channel), do: Map.fetch!(cards, channel)

  defp critical_equipment_bonus(damage, %{critical?: true} = context) do
    divisor = if Map.get(context, :skill_id), do: 200, else: 100
    damage + div(damage * Map.get(context, :crit_atk_rate, 0), divisor)
  end

  defp critical_equipment_bonus(damage, %{ignore_noncrit_atk_bonus: true}), do: damage

  defp critical_equipment_bonus(damage, context),
    do: damage + div(damage * Map.get(context, :non_crit_atk_rate, 0), 100)

  defp critical_damage(damage, %{critical?: true} = context) do
    damage
    |> Critical.multiply(Map.get(context, :crate, 0))
    |> PhysicalAttack.add_rate(-Map.get(context, :crit_def_rate, 0))
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

    center =
      200 * (base + inputs.refine_atk + Map.get(inputs, :status_watk, 0)) +
        base * inputs.primary_stat

    variance = 10 * base * inputs.weapon_level
    minimum = max(div(center - variance, 200), 0)
    maximum = min(div(center + variance, 200), 65_535)

    if inputs.critical? or inputs.max_weapon_damage?,
      do: {maximum, maximum},
      else: {minimum, maximum}
  end
end
