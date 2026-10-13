defmodule Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.PreRenewal do
  @moduledoc """
  Classic player weapon bounds and post-defense refine/mastery arithmetic.

  A hit is split at its single post-defense attribute step, which the
  coordinator owns: `pre_element/2` runs the base, its critical or positive
  non-critical equipment bonus, skill ratio, defense, refine and mastery stages;
  `post_element/2` runs the cards and final reduction. The non-critical bonus
  belongs to the weapon base only, never to the shield replacement. After
  defense the right hand keeps at least 1 damage and the left hand at least 0.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.PreRenewal, as: Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack

  @behaviour PhysicalAttack

  @doc """
  Returns the hand's normal-attack base damage: the weapon base with its
  critical or non-critical equipment rate, as a normal attack rolls it.
  """
  @spec normal_base(PhysicalAttack.parts(), PhysicalAttack.context()) :: integer()
  def normal_base(parts, context) do
    attack_bonus(base(parts, context), %{parts | source: :weapon}, context)
  end

  @doc """
  Carries a normal-attack base through the stages a classic attack also
  applies to it, the base of Magnum Break's fire share: the status ATK rate,
  the full DEF even when the attack itself ignores DEF or is critical, the
  right weapon's refine bonus, a minimum of 1, the weapon masteries
  (`mastery_atk`) and a minimum of 1 again.
  """
  @spec magnum_break_base(integer(), PhysicalAttack.context(), %{
          refine_atk: non_neg_integer(),
          mastery_atk: integer()
        }) :: integer()
  def magnum_break_base(base, context, %{refine_atk: refine, mastery_atk: mastery}) do
    defended =
      base
      |> PhysicalAttack.status_damage(context)
      |> Defense.apply_def(context.defense)

    max(max(defended + refine, 1) + mastery, 1)
  end

  @doc """
  Calculates one classic hit up to its post-defense attribute step.

  The post-defense stage (refine, minimum, masteries, post-defense status ATK)
  runs only for damage before it: a shield attack, which has no second hand
  and takes its DEF before the ratio, that has nothing left stays at 0.
  """
  @spec pre_element(PhysicalAttack.parts(), PhysicalAttack.context()) :: integer()
  def pre_element(parts, context) do
    base = attack_bonus(base(parts, context), parts, context)
    base = if parts.source == :shield, do: defend(base, context), else: base

    skilled =
      div(base * Map.get(context, :skill_ratio, 100), 100) + Map.get(context, :bonus_atk, 0)

    skilled =
      skilled
      |> PhysicalAttack.add_rate(Map.get(context, :skill_atk_rate, 0))
      |> PhysicalAttack.add_rate(-Map.get(context, :skill_taken_rate, 0))
      |> PhysicalAttack.status_damage(context)

    if parts.source == :shield and trunc(skilled) == 0 do
      0
    else
      defended = if parts.source == :shield, do: skilled, else: defend(skilled, context)

      max(trunc(defended) + parts.refine_atk, minimum(parts)) + parts.mastery_atk +
        Map.get(context, :post_defense_atk, 0)
    end
  end

  # After its refine bonus the right hand keeps at least 1 damage, the left hand
  # only 0.
  defp minimum(%{hand: :left_hand}), do: 0
  defp minimum(_parts), do: 1

  @doc """
  Finishes one classic hit after its attribute step: the attacker's cards (with
  the range rates) and then the target's, each one product.
  """
  @spec post_element(integer(), PhysicalAttack.context()) :: integer()
  def post_element(damage, context) do
    damage
    |> PhysicalAttack.attacker_cardfix(context.attacker_cards)
    |> PhysicalAttack.defender_cardfix(weapon_cards(Map.get(context, :defender_cards)))
  end

  defp weapon_cards(nil), do: nil
  defp weapon_cards(%{weapon: cards}), do: cards

  # The weapon roll (its maximum already raised by status weapon ATK) takes the
  # size fix; status ATK and the flat ATK channels join after it.
  defp base(parts, context) do
    weapon = div(parts.weapon_atk * context.size_rate, 100)

    parts.status_atk + parts.flat_atk + weapon + parts.overrefine_atk +
      Map.get(context, :flat_bonus, 0)
  end

  defp attack_bonus(damage, _parts, %{critical?: true} = context) do
    PhysicalAttack.rate(damage, max(Map.get(context, :crit_atk_rate, 0), 0))
  end

  defp attack_bonus(damage, %{source: :weapon}, context) do
    if Map.get(context, :ignore_noncrit_atk_bonus, false),
      do: damage,
      else: non_crit_bonus(damage, Map.get(context, :non_crit_atk_rate, 0))
  end

  defp attack_bonus(damage, _parts, _context), do: damage

  @doc """
  Adds a positive non-critical equipment rate's truncated share; a zero or
  negative rate leaves the damage unchanged.
  """
  @spec non_crit_bonus(integer(), integer()) :: integer()
  def non_crit_bonus(damage, rate) when rate > 0, do: damage + div(damage * rate, 100)
  def non_crit_bonus(damage, _rate), do: damage

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
    maximum = inputs.base_atk + Map.get(inputs, :status_watk, 0)
    minimum = min(div(max(inputs.dex, 0) * (80 + 20 * inputs.weapon_level), 100), maximum)
    minimum = if inputs.arrow?, do: div(minimum * maximum, 100), else: minimum
    maximum = max(minimum, maximum)

    if inputs.critical? or inputs.max_weapon_damage?,
      do: {maximum, maximum},
      else: {minimum, max(minimum, maximum - 1)}
  end
end
