defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Itemscript do
  @moduledoc """
  Temporary card script (SC_ITEMSCRIPT).

  In both modes, val1 selects a mode-loaded card program for the full player
  stat fold and val2 selects its display icon. Only one script is held: a
  greater held card ID retains its values and timer; equal or greater incoming
  IDs replace it without an unequip or genuine status-end transition.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_itemscript,
    no_dispel: true,
    no_clear_buff: false,
    flags: [:no_clearance, :no_banishing_buster],
    properties: [:buff],
    calc_flags: [:all]
end
