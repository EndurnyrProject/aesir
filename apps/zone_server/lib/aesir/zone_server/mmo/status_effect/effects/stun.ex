defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stun do
  @moduledoc """
  Stun (SC_STUN).

  Complete action prevention: no movement, attacks, skills or magic.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stun,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    opt1: :stun
end
