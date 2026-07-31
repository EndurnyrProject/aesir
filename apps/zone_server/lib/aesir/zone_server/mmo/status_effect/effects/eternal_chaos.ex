defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EternalChaos do
  @moduledoc "Finite Eternal Chaos defense-reduction snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_eternalchaos,
    no_dispel: true,
    properties: [:debuff],
    calc_flags: [:def, :def2],
    end_on_start: [
      :sc_richmankim,
      :sc_eternalchaos,
      :sc_drumbattle,
      :sc_nibelungen,
      :sc_rokisweil,
      :sc_intoabyss,
      :sc_siegfried
    ],
    duration: 60_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :eternalchaos

  @impl true
  def modifiers(_instance, _context), do: %{def_rate: -100, def2_rate: -100}
end
