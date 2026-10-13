defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IntoAbyss do
  @moduledoc """
  Into the Abyss (SC_INTOABYSS) waives gemstone costs. Renewal ends the other
  ensembles' statuses; pre-renewal ends none and lasts 60 seconds.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_intoabyss,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    end_on_start: [
      renewal: [
        :sc_richmankim,
        :sc_eternalchaos,
        :sc_drumbattle,
        :sc_nibelungen,
        :sc_rokisweil,
        :sc_intoabyss,
        :sc_siegfried
      ],
      pre_renewal: []
    ],
    duration: [renewal: 180_000, pre_renewal: 60_000],
    icon: :intoabyss
end
