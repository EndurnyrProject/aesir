defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GrandcrossRoot do
  @moduledoc """
  Grand Cross self-root (SC_GRANDCROSS_ROOT).

  The short self-inflicted immobilization a Crusader takes on when casting Grand
  Cross: it holds them in place for the roughly 950 ms the holy cross field
  ticks, so the field stays centered on them. Movement is gated through the
  standard `prevents_movement` property (`Interpreter.can_move?/2`); the status
  carries no attack or skill lock.

  Not persisted (`no_save`) and cleared on a cross-map warp
  (`remove_on_map_change`) - it is a transient cast-time root, not durable state.

  NOTE: the reference skill also suppresses the caster's own shield DEF/MDEF for
  the same window. Aesir has no shield-only defense-suppression route - equipment
  break is durable inventory state, and `def_rate`/`mdef_rate` scale all defense
  rather than the shield alone - and standing up a dedicated equipment-suppression
  subsystem is out of scope here, so shield suppression is deferred.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_grandcross_root,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    properties: [:prevents_movement],
    flags: [:no_move]
end
