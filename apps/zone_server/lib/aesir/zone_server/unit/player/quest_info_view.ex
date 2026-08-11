defmodule Aesir.ZoneServer.Unit.Player.QuestInfoView do
  @moduledoc """
  Per-player evaluation and display of NPC quest-icon bubbles (rAthena
  `pc_show_questinfo`).

  NPCs declare quest icons in their `OnInit` handlers via the `questinfo`
  DSL op, which registers them into `Aesir.ZoneServer.Npc.QuestInfo`. This
  module reads the icons for the player's current map, evaluates each icon's
  condition against the player's live state, and pushes a `QuestInfoIcon`
  packet whenever a bubble should appear, change, or clear.

  `refresh/1` runs inside the `PlayerSession` process (single writer) and is
  cheap: the conditions are pure reads over `game_state`
  (`Ctx.from_session/2`), so there is no cross-process round-trip and no
  deadlock risk. The session tracks what each NPC currently displays in
  `SessionState.quest_info_display`, so `refresh/1` only sends packets for the
  bubbles that actually changed (mirroring rAthena's `qi_display` diff).

  Triggers (map enter, item/level/job/quest changes) call `request_refresh/0`,
  which posts a coalesced `:refresh_quest_info` message to the session.
  """

  require Logger

  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.QuestInfo
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.SessionState

  # e_questinfo_types QTYPE_NONE — the icon value that clears a bubble.
  @qtype_none 9999

  @doc """
  Posts a coalesced quest-info refresh request to the current process's
  session mailbox. Called in-process from the mutation sites that can change a
  questinfo condition's outcome.
  """
  @spec request_refresh() :: :ok
  def request_refresh do
    send(self(), :refresh_quest_info)
    :ok
  end

  @doc """
  Drains any pending `:refresh_quest_info` messages from the current process's
  mailbox so a burst of mutations (a script granting several items posts one
  request each) collapses into a single `refresh/1`. Runs in the session
  process, where the `receive` reaches the coalesced messages.
  """
  @spec coalesce() :: :ok
  def coalesce do
    receive do
      :refresh_quest_info -> coalesce()
    after
      0 -> :ok
    end
  end

  @doc """
  Re-evaluates every quest icon on the player's current map and sends the
  `QuestInfoIcon` deltas, returning the session state with its display
  tracking updated.

  On a map change the previously shown bubbles are treated as cleared (the
  client discards them on map transition), so the new map's icons are sent
  fresh.
  """
  @spec refresh(SessionState.t()) :: SessionState.t()
  def refresh(%SessionState{game_state: nil} = state), do: state

  def refresh(%SessionState{game_state: gs, connection_pid: conn} = state) do
    map = gs.map_name
    prior = state.quest_info_display
    prior_shown = if prior.map == map, do: prior.shown, else: %{}

    ctx = Ctx.from_session(state, {:npc, :quest_info})

    new_shown =
      map
      |> QuestInfo.for_map()
      |> Enum.reduce(%{}, fn npc, acc ->
        apply_npc(npc, ctx, prior_shown, conn, acc)
      end)

    %{state | quest_info_display: %{map: map, shown: new_shown}}
  end

  defp apply_npc(%{gid: gid, x: x, y: y, entries: entries}, ctx, prior_shown, conn, acc) do
    previous = Map.get(prior_shown, gid)

    case desired_icon(entries, ctx) do
      {icon, color} ->
        unless previous == {icon, color}, do: send_icon(conn, gid, x, y, icon, color)
        Map.put(acc, gid, {icon, color})

      :hide ->
        if previous != nil, do: send_icon(conn, gid, x, y, @qtype_none, 0)
        acc
    end
  end

  # The first entry whose condition passes wins (rAthena breaks on first match).
  defp desired_icon([], _ctx), do: :hide

  defp desired_icon([%{condition: condition, icon: icon, color: color} | rest], ctx) do
    if passes?(condition, ctx) do
      {icon, color}
    else
      desired_icon(rest, ctx)
    end
  end

  defp passes?(nil, _ctx), do: true

  defp passes?(condition, ctx) when is_function(condition, 1) do
    condition.(ctx) == true
  rescue
    error ->
      Logger.warning("questinfo condition raised, treating as unmet: #{inspect(error)}")
      false
  end

  defp send_icon(conn, gid, x, y, icon, color) do
    MessageRouter.send_to(conn, %Aesir.Net.QuestInfoIcon{
      npc_id: gid,
      x: x,
      y: y,
      icon: icon,
      color: color
    })
  end
end
