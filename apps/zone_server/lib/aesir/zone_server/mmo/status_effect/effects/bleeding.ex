defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Bleeding do
  @moduledoc """
  Bleeding (SC_BLEEDING).

  Stops HP/SP regeneration and deals damage every 10 seconds based on the
  status level (val1).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_bleeding,
    properties: [:debuff, :damage_over_time],
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    tick_interval: 10_000

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(_instance, _context), do: %{hp_regen: -100, sp_regen: -100}

  @impl true
  def on_tick(target, instance, _context) do
    deal_damage(target, max(200 + instance.val1 * 10, 1))
    deal_damage(target, max(instance.val1 * 2, 1))
    {:ok, instance}
  end
end
