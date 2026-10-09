defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripWeapon do
  @moduledoc "Divest Weapon (SC_STRIPWEAPON)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stripweapon,
    metadata: %{strip_slot: :right_hand},
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    icon: :noequipweapon
end
