defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripShield do
  @moduledoc "Divest Shield (SC_STRIPSHIELD)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stripshield,
    metadata: %{strip_slot: :left_hand},
    no_dispel: false,
    properties: [:debuff],
    icon: :noequipshield
end
