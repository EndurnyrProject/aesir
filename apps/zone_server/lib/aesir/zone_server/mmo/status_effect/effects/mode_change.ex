defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ModeChange do
  @moduledoc """
  Mode Change (SC_MODECHANGE), the held mode override a slave runs under.

  The engine applies it directly to a monster with up to three masks: a set
  mask that replaces the first-generation mode bits, an add mask and a remove
  mask. The calculated snapshot applies them in that order and derives the
  monster class from the result. It carries no numeric modifiers, lasts until
  it is replaced, and ends on death.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_modechange,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:mode],
    permanent: true,
    remove_on_death: true
end
