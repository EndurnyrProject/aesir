defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RokisWeil do
  @moduledoc "Finite Roki's Weil skill-casting prevention."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_rokisweil,
    no_dispel: true,
    properties: [:debuff, :prevents_skills],
    end_on_start: [
      :sc_richmankim,
      :sc_eternalchaos,
      :sc_drumbattle,
      :sc_nibelungen,
      :sc_rokisweil,
      :sc_intoabyss,
      :sc_siegfried
    ],
    duration: 30_000,
    icon: :rokisweil
end
