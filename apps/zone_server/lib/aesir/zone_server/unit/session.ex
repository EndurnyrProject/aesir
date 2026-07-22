defmodule Aesir.ZoneServer.Unit.Session do
  @moduledoc """
  Type-agnostic operations on unit session processes.

  Senders that target either unit type (player or mob) go through here
  instead of casting raw tuples to a session pid directly.
  """

  @doc """
  Casts a knockback landing cell to the owning session.

  Both `PlayerSession` and `MobSession` handle it identically once dispatched:
  update position, stop movement, re-sync the spatial index/registry. The
  player session dispatches it through the `:movement` envelope; the mob
  session still expects the bare `{:knocked_back, x, y}` tag (mob envelopes
  land in a later task).
  """
  @spec knock_back(:player | :mob, pid(), integer(), integer()) :: :ok
  def knock_back(:player, pid, x, y) do
    GenServer.cast(pid, {:movement, {:knocked_back, x, y}})
  end

  def knock_back(:mob, pid, x, y) do
    GenServer.cast(pid, {:knocked_back, x, y})
  end
end
