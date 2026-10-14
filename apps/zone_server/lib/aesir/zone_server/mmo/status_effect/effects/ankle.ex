defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Ankle do
  @moduledoc """
  Ankle (SC_ANKLE), the hold of an Ankle Snare, Glacier Fist and Spiral
  Pierce, and the lock a player's own Grand Cross puts on its caster.

  The holder cannot move or teleport but can still attack and cast. Each
  applier rolls the chance and the duration itself, so the status ignores
  resistance and boss immunity; a new hold replaces one of no higher level.
  An Ankle Snare ends its target's hold when the snare ends. Identical in
  renewal and pre-renewal.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ankle,
    no_dispel: true,
    no_clear_buff: true,
    no_save: true,
    remove_on_map_change: true,
    bypass_resistance: true,
    bypass_boss_immunity: true,
    properties: [:debuff, :prevents_movement],
    flags: [:no_move],
    blocked_skills: [26],
    icon: :anklesnare
end
