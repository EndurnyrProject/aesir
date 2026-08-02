defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CpArmor do
  @moduledoc """
  Chemical Protection Armor (SC_CP_ARMOR).

  Protects the holder's armor from being broken while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cp_armor,
    no_dispel: true,
    properties: [:buff],
    end_on_start: [:sc_cp_armor],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :protectarmor
end
