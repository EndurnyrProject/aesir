defmodule Aesir.ZoneServer.Constants.DespawnReason do
  @moduledoc """
  Constants for the `Aesir.Net.UnitDespawn` `reason` field.

  These mirror rAthena's `clif_fadeout_unit`/`ZC_NOTIFY_VANISH` type codes and
  tell the client how an entity left view (so it can pick the right fade/death
  animation).
  """

  @doc "Entity left the player's area of interest."
  @spec out_of_sight() :: 0
  def out_of_sight, do: 0

  @doc "Entity died."
  @spec died() :: 1
  def died, do: 1

  @doc "Entity logged out / disconnected."
  @spec logged_out() :: 2
  def logged_out, do: 2
end
