defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcOwnerEventHandler do
  @moduledoc """
  Runs an attached NPC event for this player session on behalf of another
  subsystem -- currently only `Map.Coordinator`'s OnMyMobDead owner-event
  dispatch (rAthena `mobkillevent`), fired when a mob tagged with `event:`
  dies to this player.

  Builds the ctx the same way `NpcInteractionHandler.talk_to_npc/3` does for a
  player click (`Ctx.from_session/2` plus the target `npc_gid`), then
  delegates to `Npc.Events.trigger_attached/4`. The coordinator already
  resolved `name` to `{module, gid}`, so the only way `trigger_attached/4`
  still fails here is an undeclared label -- logged and no-op, matching
  `doevent`'s warning for the same case.
  """

  require Logger

  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Runs `label` as an attached event against `module`'s `gid` for this player
  session, using `state`'s `game_state`/`connection_pid` to build the ctx.
  """
  @spec run(module(), non_neg_integer(), String.t(), map()) :: :ok
  def run(module, gid, label, %{game_state: game_state, connection_pid: connection_pid}) do
    base_ctx =
      %{game_state: game_state, connection_pid: connection_pid}
      |> Ctx.from_session({:npc, module.npc_id()})
      |> Map.put(:npc_gid, gid)

    case NpcEvents.trigger_attached(gid, label, base_ctx, self()) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.warning("npc owner event: #{inspect(reason)} for #{inspect(label)} (gid #{gid})")

        :ok
    end
  end
end
