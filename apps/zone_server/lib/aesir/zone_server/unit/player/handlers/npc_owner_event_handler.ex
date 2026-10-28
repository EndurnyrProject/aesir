defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcOwnerEventHandler do
  @moduledoc """
  Runs an attached NPC event for this player session on behalf of another
  subsystem -- currently only `Map.Coordinator`'s OnMyMobDead owner-event
  dispatch (rAthena `mobkillevent`), fired when a mob tagged with `event:`
  dies to this player.

  The event goes through `NpcEventQueue.dispatch/3`: it starts at once for a
  free player and is queued behind the open dialog or pending skill text of a
  busy one.
  """

  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcEventQueue
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc """
  Runs `label` as an attached event against `module`'s `gid` for this player
  session, or queues it while the player is busy.
  """
  @spec run(module(), non_neg_integer(), String.t(), SessionState.t()) :: SessionState.t()
  def run(module, gid, label, state), do: NpcEventQueue.dispatch(state, gid, label, module)
end
