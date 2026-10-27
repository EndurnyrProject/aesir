defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Poison do
  @moduledoc """
  Poison (SC_POISON).

  Damage over time with a defense reduction. Each second a player loses
  `2 + max_hp * 3 / 200` HP and any other unit `2 + max_hp / 200`, only while
  its HP stays above `max(max_hp / 4, tick damage)`, so poison never kills.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_poison,
    flags: [:stop_attacking],
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :damage_over_time],
    calc_flags: [:def],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon],
    end_on_start: [:sc_concentrate, :sc_truesight],
    tick_interval: 1_000,
    opt2: :poison

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  def modifiers(_instance, %{unit_type: unit_type, target_id: target_id}) do
    if slow_poison?(unit_type, target_id) do
      %{def2_rate: -25}
    else
      %{def2_rate: -25, hp_regen: -100, sp_regen: -100}
    end
  end

  @impl true
  def on_tick(target, instance, %{target: %{hp: hp, max_hp: max_hp}}) do
    damage = if player?(target), do: 2 + div(max_hp * 3, 200), else: 2 + div(max_hp, 200)

    if not slow_poison?(target) and hp > max(div(max_hp, 4), damage),
      do: deal_damage(target, damage)

    {:ok, instance}
  end

  defp slow_poison?({unit_type, target_id}), do: slow_poison?(unit_type, target_id)

  defp slow_poison?(unit_type, target_id),
    do: StatusStorage.has_status?(unit_type, target_id, :sc_slowpoison)
end
