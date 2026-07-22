defmodule Aesir.ZoneServer.Unit.Session.Motion do
  @moduledoc """
  Shared knockback landing for both unit types.

  Owns the single mutation whose body used to be copy-pasted across the
  player and mob sessions: `knocked_back/4` clears the unit's in-flight walk,
  writes the landing cell, and publishes it - through the
  `Unit.Session.Adapter`'s `stop_movement/1` and `set_position/2` so the
  concrete state shape stays per-type.

  Side effects run in the adapter's documented order: `stop_movement/1` first
  (a pure accessor - no publish) so the standing movement state is already on
  the struct when `set_position/2` writes the landing cell and publishes it
  through `Aesir.ZoneServer.Unit.Movement.set_position/4`. The published
  snapshot never shows a unit still mid-walk at its old cell.

  What deliberately stays out of here (the "honest share"): walk-delay. Both
  sessions apply the same delay-until bookkeeping (`apply_walk_delay/3` on
  their own state struct), but the stop that follows diverges by type - a mob
  unconditionally resets its movement state with no publish and no packet; a
  player only stops (and only then) if it was actually moving, and that stop
  sends a `MoveStop` packet to the player and broadcasts one to nearby
  observers. Routing that through the adapter's pure, non-publishing
  `stop_movement/1` would either drop the player's packet or send one to an
  idle player - both are new observable behavior, which this convergence must
  not introduce. Walk-delay stays fully per-type.
  """

  alias Aesir.ZoneServer.Unit.Session.Adapter

  @type state :: Adapter.state()

  @doc """
  Lands the unit at `{x, y}` after a knockback.

  Stops its in-flight walk, then writes and publishes the new position.
  """
  @spec knocked_back(state(), integer(), integer(), module()) :: state()
  def knocked_back(state, x, y, adapter) do
    state
    |> adapter.stop_movement()
    |> adapter.set_position({x, y})
  end
end
