defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Ankle do
  @moduledoc """
  Ankle (SC_ANKLE), the immobilise Glacier Fist inflicts.

  The holder cannot move or teleport but can still attack and cast. Glacier
  Fist rolls the chance and the duration itself (shorter against high AGI, a
  fifth of the base against a boss), so the status ignores resistance and boss
  immunity. Identical in renewal and pre-renewal.

  Distinct from the trap-linked Ankle Snare status (`sc_anklesnare`), which a
  Hunter trap owns and releases.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ankle,
    no_dispel: true,
    no_save: true,
    remove_on_map_change: true,
    bypass_resistance: true,
    bypass_boss_immunity: true,
    properties: [:debuff, :prevents_movement],
    flags: [:no_move],
    blocked_skills: [26],
    icon: :anklesnare
end
