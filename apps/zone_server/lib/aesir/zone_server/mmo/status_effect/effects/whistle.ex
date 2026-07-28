defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Whistle do
  @moduledoc "Finite Whistle flee and perfect-dodge snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_whistle,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:flee, :perfect_dodge],
    end_on_start: [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :whistle

  @impl true
  def modifiers(instance, _context) do
    %{flee: instance.val2, perfect_dodge: instance.val3}
  end
end
