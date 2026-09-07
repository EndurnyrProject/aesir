defmodule Aesir.ZoneServer.Mmo.Mechanics.MagicDamage.Renewal do
  @moduledoc "Renewal ordinary magic damage arithmetic."

  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.Renewal, as: Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage

  @behaviour MagicDamage

  @impl true
  @spec calculate(integer(), MagicDamage.context()) :: pos_integer()
  def calculate(matk, context) do
    matk
    |> attacker_cardfix(context.attack)
    |> MagicDamage.defender_cardfix(context.taken)
    |> MagicDamage.skill_rate(context.smatk)
    |> MagicDamage.skill_damage(context)
    |> MagicDamage.skill_rate(-context.skill_taken_rate)
    |> DamageShared.res_reduction(context.mres)
    |> apply_defense(context)
    |> trunc()
    |> MagicDamage.skill_rate(context.skill_atk_rate)
    |> Kernel.*(context.element_modifier)
    |> DamageShared.clamp_min_one()
  end

  @impl true
  @spec attacker_cardfix(integer(), MagicDamage.attack_rates()) :: integer()
  def attacker_cardfix(damage, cards) do
    damage
    |> cardfix(cards.size)
    |> cardfix(cards.race2)
    |> cardfix(cards.element_target)
    |> cardfix(cards.atk_ele)
    |> cardfix(cards.race)
    |> cardfix(cards.class)
  end

  defp apply_defense(damage, %{ignore_mdef?: true}), do: damage

  defp apply_defense(damage, context) do
    rate = min(max(context.ignore_mdef_rate, 0), 100)
    hard = div(context.hard_mdef * (100 - rate), 100)
    Defense.apply_mdef(damage, %{hard_mdef: hard, soft_mdef: context.soft_mdef})
  end

  defp cardfix(damage, rate), do: damage - div(damage * (100 - max(0, 100 + rate)), 100)
end
