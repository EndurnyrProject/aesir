defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Scresist do
  @moduledoc """
  Status resistance (SC_SCRESIST).

  The status defense adds `val1` percent to the `sc_def` share of every status
  with a defense recipe applied to the holder, ahead of Siegfried; at 100 only a
  negative flat `sc_def2` term can still land one. Granted by Gospel's "immunity to all status" blessing and
  by item scripts; identical in both game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_scresist,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff]
end
