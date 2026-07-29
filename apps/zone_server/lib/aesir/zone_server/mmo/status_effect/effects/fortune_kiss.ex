defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FortuneKiss do
  @moduledoc "Finite Lady Luck critical snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fortunekiss,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:critical],
    end_on_start: [:sc_humming, :sc_dontforgetme, :sc_fortunekiss, :sc_serviceforyou],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :fortunekiss

  @impl true
  def modifiers(instance, _context) do
    %{critical: instance.val1, critical_rate: 2 * instance.val1}
  end
end
