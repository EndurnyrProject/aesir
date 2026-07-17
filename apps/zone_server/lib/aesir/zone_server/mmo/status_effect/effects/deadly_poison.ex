defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DeadlyPoison do
  @moduledoc """
  Deadly Poison (SC_DPOISON).

  Strong damage over time that stops regeneration and reduces defense.
  Following rAthena, the tick only damages while HP stays above
  `max(max_hp / 4, tick damage)`: players take `2 + max_hp / 50`, monsters
  `2 + max_hp / 100`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_dpoison,
    no_dispel: false,
    properties: [:debuff, :damage_over_time],
    calc_flags: [:def, :regen],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon],
    prevented_by: [:sc_refresh, :sc_inspiration],
    tick_interval: 1_000,
    opt2: :dpoison

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(_instance, _context) do
    %{hp_regen: -100, sp_regen: -100, def_rate: -25}
  end

  @impl true
  def on_tick(target, instance, context) do
    stats = context.target

    damage =
      if player?(target) do
        2 + div(stats.max_hp, 50)
      else
        2 + div(stats.max_hp, 100)
      end

    if stats.hp > max(div(stats.max_hp, 4), damage) do
      deal_damage(target, max(damage, 1))
    end

    {:ok, instance}
  end
end
