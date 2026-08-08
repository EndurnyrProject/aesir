defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripWeapon do
  @moduledoc "Divest Weapon (SC_STRIPWEAPON)."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stripweapon,
    metadata: %{strip_slot: :right_hand},
    no_dispel: false,
    properties: [:debuff],
    bypass_resistance: true,
    icon: :noequipweapon
end
