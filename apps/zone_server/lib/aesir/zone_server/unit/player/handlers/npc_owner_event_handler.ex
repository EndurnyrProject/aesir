defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcOwnerEventHandler do
  @moduledoc """
  Runs an attached NPC event for this player session on behalf of another
  subsystem -- currently only `Map.Coordinator`'s OnMyMobDead owner-event
  dispatch (rAthena `mobkillevent`), fired when a mob tagged with `event:`
  dies to this player.

  Builds the ctx the same way `NpcInteractionHandler.talk_to_npc/3` does for a
  player click (`Ctx.from_session/2` plus the target `npc_gid`), then
  delegates to `Npc.Events.trigger_attached/4`. The event shares the player's
  interaction lock with NPC dialogs and pending skill text; a busy player drops
  the event rather than starting a second interaction.
  """

  require Logger

  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc """
  Runs `label` as an attached event against `module`'s `gid` for this player
  session and returns the state with its interaction lock when started.
  """
  @spec run(module(), non_neg_integer(), String.t(), SessionState.t()) :: SessionState.t()
  def run(module, gid, label, state) do
    if SessionState.interaction_blocked?(state) do
      state
    else
      start_event(module, gid, label, state)
    end
  end

  defp start_event(module, gid, label, state) do
    base_ctx =
      state
      |> Ctx.from_session({:npc, module.npc_id()})
      |> Map.put(:npc_gid, gid)

    case NpcEvents.trigger_attached(gid, label, base_ctx, self()) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        %{state | interaction_lock: {pid, ref, gid}}

      {:error, reason} ->
        Logger.warning("npc owner event: #{inspect(reason)} for #{inspect(label)} (gid #{gid})")
        state
    end
  end
end
