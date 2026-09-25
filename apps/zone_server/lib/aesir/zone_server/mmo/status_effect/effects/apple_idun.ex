defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AppleIdun do
  @moduledoc "Renewal Idun is a finite snapshot; pre-renewal holds a field buff that lingers on exit."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_appleidun,
    no_dispel: true,
    no_save: [renewal: false, pre_renewal: true],
    properties: [:buff],
    calc_flags: [:max_hp_rate],
    end_on_start: [
      renewal: [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun],
      pre_renewal: []
    ],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :appleidun

  @impl true
  def modifiers(instance, _context), do: %{max_hp_rate: instance.val2}
end
