defmodule Aesir.ZoneServer.Mmo.Mechanics.MagicDamage.PreRenewal do
  @moduledoc "Classic ordinary magic damage arithmetic."

  alias Aesir.ZoneServer.Mmo.Mechanics.Defense.PreRenewal, as: Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage

  @behaviour MagicDamage

  @impl true
  @spec pre_element(integer(), MagicDamage.context()) :: pos_integer()
  def pre_element(matk, context) do
    matk
    |> MagicDamage.skill_damage(context)
    |> MagicDamage.skill_rate(context.skill_atk_rate)
    |> MagicDamage.skill_rate(-context.skill_taken_rate)
    |> apply_defense(context)
    |> trunc()
    |> max(1)
  end

  @impl true
  @spec post_element(integer(), MagicDamage.context()) :: integer()
  def post_element(damage, context) do
    damage
    |> attacker_cardfix(context.attack)
    |> MagicDamage.defender_cardfix(context.taken)
  end

  @impl true
  @spec attacker_cardfix(integer(), MagicDamage.attack_rates()) :: integer()
  def attacker_cardfix(damage, cards) do
    factor =
      1000
      |> MagicDamage.factor(cards.race + cards.race2)
      |> MagicDamage.factor(cards.element_target)
      |> MagicDamage.factor(cards.atk_ele)
      |> MagicDamage.factor(cards.size)
      |> MagicDamage.factor(cards.class)

    MagicDamage.apply_factor(damage, factor)
  end

  defp apply_defense(damage, %{ignore_mdef?: true}), do: damage

  defp apply_defense(damage, context) do
    rate = min(max(context.ignore_mdef_rate, 0), 100)
    hard = context.hard_mdef - div(context.hard_mdef * rate, 100)
    Defense.apply_mdef(damage, %{hard_mdef: hard, soft_mdef: context.soft_mdef})
  end
end
