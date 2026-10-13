defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RokisWeil do
  @moduledoc """
  Roki's Weil (SC_ROKISWEIL) blocks skills. Renewal forbids starting any skill
  cast and ends the other ensembles' statuses. Pre-renewal blocks every skill
  but Adaptation, also when a cast completes, ends no other status and lasts
  60 seconds. A status-immune target resists it.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_rokisweil,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:debuff, :prevents_skills],
    allow_skills: [renewal: [], pre_renewal: [304]],
    immunity: [:boss],
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
    duration: [renewal: 30_000, pre_renewal: 60_000],
    icon: :rokisweil
end
