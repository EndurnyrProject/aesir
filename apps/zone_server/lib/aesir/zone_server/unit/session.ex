defmodule Aesir.ZoneServer.Unit.Session do
  @moduledoc """
  Type-agnostic operations on unit session processes.

  Senders that target either unit type (player or mob) go through here
  instead of casting raw tuples to a session pid directly.
  """

  @doc """
  Casts a knockback landing cell to the owning session.

  Both `PlayerSession` and `MobSession` handle `{:knocked_back, x, y}`
  identically today: update position, stop movement, re-sync the spatial
  index/registry.
  """
  @spec knock_back(:player | :mob, pid(), integer(), integer()) :: :ok
  def knock_back(_unit_type, pid, x, y) do
    GenServer.cast(pid, {:knocked_back, x, y})
  end
end
