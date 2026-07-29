defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DontForgetMe do
  @moduledoc "Finite Slow Grace ASPD and movement-speed snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_dontforgetme,
    no_dispel: true,
    properties: [:debuff],
    calc_flags: [:aspd, :speed],
    end_on_start: [
      :sc_humming,
      :sc_dontforgetme,
      :sc_fortunekiss,
      :sc_serviceforyou,
      :sc_increaseagi,
      :sc_adrenaline,
      :sc_adrenaline2,
      :sc_spearquicken,
      :sc_twohandquicken,
      :sc_onehand,
      :sc_acceleration,
      :sc_merc_quicken
    ],
    conflicts_with: [:sc_speedup1],
    duration: 60_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :dontforgetme

  @impl true
  def modifiers(instance, _context) do
    %{aspd_rate: -3 * instance.val1, movement_speed: 5 + 2 * instance.val1}
  end
end
