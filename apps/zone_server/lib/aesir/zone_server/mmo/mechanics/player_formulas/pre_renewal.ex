defmodule Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas.PreRenewal do
  @moduledoc """
  Classic formulas use level-based HIT/FLEE, integer weapon-delay ASPD, split MATK bounds,
  classic defensive stats, and no trait-derived combat slots.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas

  @impl true
  def base_atk(values, ranged?) do
    {primary, secondary} =
      if ranged?, do: {values.dex, values.str}, else: {values.str, values.dex}

    primary = max(primary, 0)
    secondary = max(secondary, 0)
    luk = max(values.luk, 0)

    primary + div(primary, 10) ** 2 + div(secondary, 5) + div(luk, 5)
  end

  @impl true
  def base_def(_values), do: 0

  @impl true
  def base_matk(%{int: int}) do
    int = max(int, 0)
    %{min: int + div(int, 7) ** 2, max: int + div(int, 5) ** 2}
  end

  @impl true
  def soft_mdef(%{int: int, vit: vit}), do: max(int, 0) + div(max(vit, 0), 2)

  @impl true
  def hit(%{base_level: level, dex: dex, flat_bonus: flat_bonus}) do
    max(level + max(dex, 0) + flat_bonus, 1)
  end

  @impl true
  def flee(%{base_level: level, agi: agi, flat_bonus: flat_bonus}) do
    max(level + max(agi, 0) + flat_bonus, 1)
  end

  @impl true
  def critical(%{luk: luk, raw_luk: _raw_luk}) do
    %{strategy: :exact_tenths, base_rate: 10 + div(max(luk, 0) * 10, 3)}
  end

  @impl true
  def perfect_dodge(%{luk: luk}), do: max(luk, 0) + 10

  @impl true
  def aspd(inputs) do
    agi = max(inputs.agi, 0)
    dex = max(inputs.dex, 0)

    amotion =
      case inputs.left_weapon_delay do
        nil -> inputs.weapon_delay
        left_delay -> div((inputs.weapon_delay + left_delay) * 7, 10)
      end

    amotion = amotion - div(amotion * (4 * agi + dex), 1_000)
    amotion = amotion - 10 * inputs.flat_bonus
    rate = 1_000 - 10 * inputs.rate_bonus + inputs.penalty_rate
    amotion = div(amotion * max(rate, 0), 1_000)

    (200 - div(max(amotion, 1), 10))
    |> min(190)
    |> max(0)
  end

  @impl true
  def max_hp(inputs) do
    inputs.base_hp
    |> Kernel.*(1.0 + max(inputs.vit, 0) * 0.01)
    |> apply_transcendent_bonus(inputs.transcendent?)
    |> Kernel.+(inputs.flat_bonus + inputs.equipment_vit)
    |> apply_max_rates(inputs.equipment_rate, inputs.modifier_rate)
    |> max(1)
  end

  @impl true
  def max_sp(inputs) do
    inputs.base_sp
    |> Kernel.*(1.0 + max(inputs.int, 0) * 0.01)
    |> apply_transcendent_bonus(inputs.transcendent?)
    |> Kernel.+(inputs.flat_bonus + inputs.equipment_int)
    |> apply_max_rates(inputs.equipment_rate, inputs.modifier_rate)
    |> max(1)
  end

  @impl true
  def trait_slots(_values, _bonuses) do
    %{patk: 0, smatk: 0, res: 0, mres: 0, hplus: 0, crate: 0}
  end

  defp apply_transcendent_bonus(value, true), do: value * 1.25
  defp apply_transcendent_bonus(value, false), do: value

  defp apply_max_rates(value, equipment_rate, modifier_rate) do
    equipment_adjusted = value * (100 + equipment_rate) / 100
    trunc(equipment_adjusted) + trunc(equipment_adjusted * modifier_rate / 100)
  end
end
