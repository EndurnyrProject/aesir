defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Intimidate do
  @moduledoc """
  Intimidate (SC_INTIMIDATE), a brief marker after Snatch warps its participants.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_intimidate,
    no_dispel: false,
    no_save: true,
    duration: 800,
    icon: nil
end
