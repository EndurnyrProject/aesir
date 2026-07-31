defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DrumBattle do
  @moduledoc "Finite Drum of the Battlefield ATK and DEF snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_drumbattle,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:atk, :def],
    end_on_start: [
      :sc_richmankim,
      :sc_eternalchaos,
      :sc_drumbattle,
      :sc_nibelungen,
      :sc_rokisweil,
      :sc_intoabyss,
      :sc_siegfried
    ],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :drumbattlefield

  @impl true
  def modifiers(instance, _context), do: %{atk: 15 + 5 * instance.val1, def: 15 * instance.val1}
end
