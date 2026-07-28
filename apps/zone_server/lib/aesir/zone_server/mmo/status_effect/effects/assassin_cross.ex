defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AssassinCross do
  @moduledoc "Finite Assassin Cross of Sunset ASPD snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_assncross,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:aspd],
    end_on_start: [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :assassincross

  @impl true
  def modifiers(instance, _context), do: %{aspd: instance.val2}
end
