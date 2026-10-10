defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sleep do
  @moduledoc """
  Sleep (SC_SLEEP).

  The target is asleep and cannot act. Any active damage wakes it up.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sleep,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic, :remove_on_damaged],
    prevented_by: [
      renewal: [:sc_refresh, :sc_inspiration, :sc_gvg_sleep, :sc_sleep, :sc_protection],
      pre_renewal: [:sc_refresh, :sc_inspiration, :sc_gvg_sleep, :sc_sleep]
    ],
    opt1: :sleep
end
