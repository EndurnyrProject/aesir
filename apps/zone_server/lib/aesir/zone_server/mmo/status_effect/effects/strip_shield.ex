defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripShield do
  @moduledoc "Divest Shield (SC_STRIPSHIELD)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stripshield,
    metadata: %{strip_slot: :left_hand},
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    icon: :noequipshield
end
