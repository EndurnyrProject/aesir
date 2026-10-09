defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adaptation do
  @moduledoc """
  Adaptation to Circumstances (SC_ADAPTATION), a finite Bard SP-cost buff.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adaptation,
    no_dispel: [renewal: false, pre_renewal: true],
    no_clear_buff: [renewal: false, pre_renewal: true],
    properties: [:buff],
    duration: 300_000,
    icon: :adaptation
end
