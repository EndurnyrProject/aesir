defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AppleIdun do
  @moduledoc "Finite Apple of Idun maximum-HP snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_appleidun,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:max_hp_rate],
    end_on_start: [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :appleidun

  @impl true
  def modifiers(instance, _context), do: %{max_hp_rate: instance.val2}
end
