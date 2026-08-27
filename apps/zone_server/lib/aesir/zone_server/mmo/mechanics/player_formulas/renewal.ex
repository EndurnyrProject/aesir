defmodule Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas.Renewal do
  @moduledoc """
  Renewal formulas use trait attributes, AGI/DEX-scaled ASPD, and the current HP/SP model.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas

  @impl true
  def base_atk(%{str: str, pow: pow, base_level: level}, _ranged?) do
    trunc(str + level / 4) + 5 * pow
  end

  @impl true
  def base_def(%{vit: vit, base_level: level}), do: trunc(vit / 2 + level / 6)

  @impl true
  def base_matk(%{int: int, dex: dex, luk: luk, spl: spl, base_level: level}) do
    matk = int + div(int, 2) + div(dex, 5) + div(luk, 3) + div(level, 4) + 5 * spl
    %{min: matk, max: matk}
  end

  @impl true
  def soft_mdef(%{int: int, dex: dex, vit: vit, base_level: level}) do
    int + div(level, 4) + div(dex + vit, 5)
  end

  @impl true
  def hit_rate_base, do: 0

  @impl true
  def hit(%{dex: dex, luk: luk, con: con, base_level: level, flat_bonus: flat_bonus}) do
    trunc(dex + luk / 3 + level / 4) + 2 * con + flat_bonus + 175
  end

  @impl true
  def flee(%{agi: agi, luk: luk, con: con, base_level: level, flat_bonus: flat_bonus}) do
    trunc(agi + luk / 5 + level / 4) + 2 * con + flat_bonus + 100
  end

  @impl true
  def critical(%{luk: luk, raw_luk: raw_luk}) do
    %{
      strategy: :display_first,
      display_base: trunc(luk / 3),
      roll_rate: raw_luk |> then(&div(&1 * 10, 3)) |> max(0) |> min(1_000),
      roll_display_base: div(raw_luk, 3)
    }
  end

  @impl true
  def perfect_dodge(%{luk: luk}), do: trunc(luk / 5)

  @impl true
  def aspd(inputs) do
    stat_term =
      if inputs.ranged? do
        inputs.dex * inputs.dex / 7 + inputs.agi * inputs.agi / 2
      else
        inputs.dex * inputs.dex / 5 + inputs.agi * inputs.agi / 2
      end

    base_aspd = :math.sqrt(stat_term) * 0.25 + 196

    final_aspd =
      trunc(base_aspd + inputs.flat_bonus * inputs.agi / 200) -
        min(inputs.weapon_delay, 200)

    final_aspd =
      final_aspd + div(max(195 - final_aspd, 2) * inputs.rate_bonus, 100)

    final_aspd
    |> apply_aspd_penalty(inputs.penalty_rate)
    |> min(193)
    |> max(0)
  end

  @impl true
  def max_hp(inputs) do
    hp_with_vit = trunc(inputs.base_hp * (1.0 + inputs.vit * 0.01))

    hp_with_factor =
      if inputs.hp_factor > 0 do
        trunc(hp_with_vit * (100 + inputs.hp_factor) / 100)
      else
        hp_with_vit
      end

    hp_with_factor
    |> Kernel.+(inputs.hp_increase + inputs.flat_bonus)
    |> apply_max_rate(inputs.equipment_rate + inputs.modifier_rate)
    |> max(1)
  end

  @impl true
  def max_sp(inputs) do
    inputs.base_sp
    |> Kernel.*(1.0 + inputs.int * 0.01)
    |> trunc()
    |> Kernel.+(inputs.sp_increase + inputs.flat_bonus)
    |> apply_max_rate(inputs.equipment_rate + inputs.modifier_rate)
    |> max(1)
  end

  @impl true
  def trait_slots(values, bonuses) do
    %{
      patk: combat_modifier(bonuses.patk, div(values.pow, 3) + div(values.con, 5)),
      smatk: combat_modifier(bonuses.smatk, div(values.spl, 3) + div(values.con, 5)),
      res: combat_modifier(bonuses.res, values.sta + div(values.sta, 3) * 5),
      mres: combat_modifier(bonuses.mres, values.wis + div(values.wis, 3) * 5),
      hplus: combat_modifier(bonuses.hplus, values.crt),
      crate: combat_modifier(bonuses.crate, div(values.crt, 3))
    }
  end

  defp apply_aspd_penalty(aspd, penalty_rate) do
    200 - div((200 - aspd) * (1_000 + penalty_rate), 1_000)
  end

  defp apply_max_rate(value, rate), do: trunc(value * (100 + rate) / 100)

  defp combat_modifier(bonus, trait_term), do: (bonus + trait_term) |> max(0) |> min(32_767)
end
