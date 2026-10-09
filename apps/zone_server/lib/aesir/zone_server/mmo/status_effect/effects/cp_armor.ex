defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CpArmor do
  @moduledoc """
  Chemical Protection Armor (SC_CP_ARMOR).

  Protects the holder's armor from being broken while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cp_armor,
    no_dispel: true,
    no_clear_buff: true,
    clear_buff_flags: [:remove_chemical_protect, :remove_on_hermode],
    properties: [:buff],
    end_on_start: [:sc_cp_armor],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :protectarmor
end
