defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ServiceForYou do
  @moduledoc "Finite Gypsy's Kiss maximum-SP and SP-cost snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_serviceforyou,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:max_sp_rate],
    end_on_start: [:sc_humming, :sc_dontforgetme, :sc_fortunekiss, :sc_serviceforyou],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :serviceforyou

  @impl true
  def modifiers(instance, _context) do
    level = instance.val1
    max_sp_rate = if level < 10, do: 9 + level, else: 20

    %{max_sp_rate: max_sp_rate, sp_cost_rate: -(5 + level)}
  end
end
