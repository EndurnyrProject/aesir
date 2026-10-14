defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AddAtkDamage do
  @moduledoc """
  Added physical-damage buff (SC_ADD_ATK_DAMAGE).

  Adds `val1` percent to the holder's weapon hits after the target's damage
  reductions and before its blockers; the damage stage reads it by id.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_add_atk_damage,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    icon: :add_atk_damage
end
