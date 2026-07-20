defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Poison do
  @moduledoc """
  Poison (SC_POISON).

  Damage over time with a defense reduction. Damage per tick follows rAthena:
  players take `2 + max_hp * 3 / 200`, monsters `2 + max_hp / 200`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_poison,
    no_dispel: false,
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
  def on_tick(target, instance, context) do
    unless slow_poison?(target) do
      stats = context.target

      damage =
        if player?(target) do
          2 + div(stats.max_hp * 3, 200)
        else
          2 + div(stats.max_hp, 200)
        end

      deal_damage(target, max(damage, 1))
    end

    {:ok, instance}
  end

  defp slow_poison?({unit_type, target_id}), do: slow_poison?(unit_type, target_id)

  defp slow_poison?(unit_type, target_id),
    do: StatusStorage.has_status?(unit_type, target_id, :sc_slowpoison)
end
