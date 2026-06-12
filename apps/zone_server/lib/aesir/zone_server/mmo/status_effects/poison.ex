defmodule Aesir.ZoneServer.Mmo.StatusEffects.Poison do
  @moduledoc """
  Poison (SC_POISON).

  Damage over time with a defense reduction. Damage per tick follows rAthena:
  players take `2 + max_hp * 3 / 200`, monsters `2 + max_hp / 200`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_poison,
    properties: [:debuff, :damage_over_time],
    calc_flags: [:def],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon],
    end_on_start: [:sc_concentrate, :sc_truesight],
    tick_interval: 1_000

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(_instance, _context), do: %{def2: -25}

  @impl true
  def on_tick(target, instance, context) do
    stats = context.target

    damage =
      if player?(target) do
        2 + div(stats.max_hp * 3, 200)
      else
        2 + div(stats.max_hp, 200)
      end

    deal_damage(target, max(damage, 1))
    {:ok, instance}
  end
end
