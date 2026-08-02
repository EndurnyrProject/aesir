defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CpShield do
  @moduledoc """
  Chemical Protection Shield (SC_CP_SHIELD).

  Protects the holder's shield from being broken while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cp_shield,
    no_dispel: true,
    properties: [:buff],
    end_on_start: [:sc_cp_shield],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :protectshield
end
