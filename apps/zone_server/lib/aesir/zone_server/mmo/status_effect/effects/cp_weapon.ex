defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CpWeapon do
  @moduledoc """
  Chemical Protection Weapon (SC_CP_WEAPON).

  Protects the holder's weapon from being broken while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cp_weapon,
    no_dispel: true,
    no_clear_buff: true,
    clear_buff_flags: [:remove_chemical_protect, :remove_on_hermode],
    properties: [:buff],
    end_on_start: [:sc_cp_weapon],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :protectweapon
end
