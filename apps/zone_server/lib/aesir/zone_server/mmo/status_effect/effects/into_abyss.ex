defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IntoAbyss do
  @moduledoc "Finite Into the Abyss gemstone-cost waiver."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_intoabyss,
    no_dispel: true,
    properties: [:buff],
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
    icon: :intoabyss
end
