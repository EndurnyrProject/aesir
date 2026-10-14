defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AddMatkDamage do
  @moduledoc """
  Added magic-damage buff (SC_ADD_MATK_DAMAGE).

  Adds `val1` percent to the holder's magic hits after the target's damage
  reductions and before its blockers; the damage stage reads it by id.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_add_matk_damage,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    icon: :add_matk_damage
end
