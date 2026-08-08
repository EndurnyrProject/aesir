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

  For the same window it also suppresses the caster's own shield: the DEF and
  MDEF the equipped shield contributes are captured at cast time and carried as
  `val1`/`val2`, then emitted as negative flat `:def`/`:mdef` modifiers, so the
  Crusader takes the field's holy damage (and any hit landing during the root)
  without the shield's protection. The shield's defense returns when the status
  ends. A caster with no shield carries zero and the modifier is a no-op.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_grandcross_root,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    calc_flags: [:def, :mdef],
    properties: [:prevents_movement],
    flags: [:no_move]

  @impl true
  def modifiers(instance, _context) do
    %{def: -(instance.val1 || 0), mdef: -(instance.val2 || 0)}
  end
end
