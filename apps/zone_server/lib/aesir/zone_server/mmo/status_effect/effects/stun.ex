defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stun do
  @moduledoc """
  Stun (SC_STUN).

  Complete action prevention: no movement, attacks, skills or magic.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stun,
    immunity: [:boss],
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic, :stop_attacking],
    prevented_by: [
      renewal: [:sc_refresh, :sc_inspiration, :sc_gvg_stun, :sc_stun, :sc_protection],
      pre_renewal: [:sc_refresh, :sc_inspiration, :sc_gvg_stun, :sc_stun]
    ],
    opt1: :stun
end
