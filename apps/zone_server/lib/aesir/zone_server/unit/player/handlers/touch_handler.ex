defmodule Aesir.ZoneServer.Unit.Player.Handlers.TouchHandler do
  @moduledoc """
  NPC trigger areas for a player session: entering, leaving, and the
  `OnTouch_` one-toucher rule.

  The scan (`scan/1`) runs whenever the player lands on a cell: each walk
  step, a knockback, the map-load acknowledgement, the end of a concealing
  status, and an NPC in whose area the player stands becoming visible. The
  caller resolves the warp under the player first (`warp_underfoot/1`); a
  fired warp ends the scan. For every visible trigger area containing the
  player and not yet entered, the NPC's labels decide what fires:

  - `OnTouch_`: one player at a time (`Npc.Touch`). A dead player, an NPC
    already attached to someone else, or a concealed player (Hiding,
    Cloaking, Chase Walk) skips the NPC outright: nothing falls through to
    `OnTouch` or the click. The first eligible player claims the NPC and the
    area counts as entered for it; the others are re-evaluated on every
    later scan.
  - `OnTouch`: fires for every player entering, concealed or not.
  - neither: the click fallback (`on_talk/1`), skipped for a busy player.

  A dead player triggers nothing. Fired, claimed and queued areas join
  `PlayerState.inside_npc_areas`; `leave_areas/1` drops the ones the player
  has left before each scan and `leave_all/1` drops them all on warp and
  logout. Leaving an `OnTouch_` area the player holds releases the claim and
  hands it to the first other eligible player still inside, through a cast
  the receiving session validates itself (`handle_handoff/3`).
  """

  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession
  alias Aesir.ZoneServer.Npc.Touch
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Concealment
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcEventQueue
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  The warp whose area contains the player's cell, or `nil`. A dead player
  triggers no warp; a concealed player triggers only warps that fire for
  hidden players, so an ordinary warp underfoot yields to a hidden-trigger
  warp sharing the cell. Concealment is read only when an ordinary warp is
  underfoot.
  """
  @spec warp_underfoot(PlayerState.t()) :: Warp.t() | nil
  def warp_underfoot(%{action_state: :dead}), do: nil

  def warp_underfoot(%{map_name: map, x: x, y: y, character_id: char_id}) do
    warps = warps_for_map(map)

    case Warp.Registry.hit?(warps, x, y) do
      %Warp{trigger_on_hidden: false} = warp ->
        if Concealment.unit_concealed?(:player, char_id),
          do: warps |> Enum.filter(& &1.trigger_on_hidden) |> Warp.Registry.hit?(x, y),
          else: warp

      other ->
        other
    end
  end

  @doc """
  Drops every entered area that no longer contains the player, handing off
  the `OnTouch_` claims it held.
  """
  @spec leave_areas(SessionState.t()) :: SessionState.t()
  def leave_areas(%{game_state: game_state} = state) do
    {kept, left} = Enum.split_with(game_state.inside_npc_areas, &still_inside?(&1, game_state))
    Enum.each(left, &release_claim(&1, game_state))
    %{state | game_state: %{game_state | inside_npc_areas: MapSet.new(kept)}}
  end

  @doc """
  Hands off every `OnTouch_` claim the player holds; for a player leaving the
  map. Only the claims are touched: the caller resets `inside_npc_areas`.
  """
  @spec leave_all(PlayerState.t()) :: :ok
  def leave_all(%PlayerState{} = game_state) do
    Enum.each(game_state.inside_npc_areas, &release_claim(&1, game_state))
  end

  @doc """
  Evaluates every visible trigger area containing the player's cell that it
  has not entered yet. The caller has already ruled out a warp underfoot.
  """
  @spec scan(SessionState.t()) :: SessionState.t()
  def scan(%{game_state: %{action_state: :dead}} = state), do: state

  def scan(%{game_state: game_state} = state) do
    game_state.map_name
    |> NpcRegistry.touch_rects()
    |> Enum.filter(fn {gid, xs, ys} ->
      game_state.x in xs and game_state.y in ys and
        not MapSet.member?(game_state.inside_npc_areas, gid) and NpcSession.visible?(gid)
    end)
    |> Enum.reduce(state, fn {gid, _xs, _ys}, acc -> touch(acc, gid) end)
  end

  @doc """
  Receives an `OnTouch_` handoff for `gid`. The player claims and runs (or
  queues) it when it is still inside the area, alive, not concealed and not
  warping; otherwise the handoff moves on to the next player in the area,
  skipping `excluded` and this player.
  """
  @spec handle_handoff(SessionState.t(), non_neg_integer(), MapSet.t()) :: SessionState.t()
  def handle_handoff(%{game_state: game_state} = state, gid, excluded) do
    cond do
      not eligible?(game_state) or not still_inside?(gid, game_state) ->
        hand_off(gid, MapSet.put(excluded, game_state.character_id))
        state

      Touch.claim(gid, game_state.character_id) == :taken ->
        state

      true ->
        state |> enter(gid) |> NpcEventQueue.dispatch(gid, "OnTouch_")
    end
  end

  defp touch(%{game_state: game_state} = state, gid) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {module, _placement}} ->
        events = module.events()

        cond do
          "OnTouch_" in events -> touch_once(state, gid)
          "OnTouch" in events -> state |> enter(gid) |> NpcEventQueue.dispatch(gid, "OnTouch")
          true -> click_fallback(state |> enter(gid), gid, game_state)
        end

      :error ->
        state
    end
  end

  defp touch_once(%{game_state: game_state} = state, gid) do
    me = game_state.character_id

    cond do
      Touch.toucher(gid) not in [nil, me] -> state
      Concealment.unit_concealed?(:player, me) -> state
      Touch.claim(gid, me) == :taken -> state
      true -> state |> enter(gid) |> NpcEventQueue.dispatch(gid, "OnTouch_")
    end
  end

  defp click_fallback(state, gid, game_state) do
    if SessionState.in_script?(state) do
      state
    else
      {:noreply, state} = NpcInteractionHandler.talk_to_npc(gid, game_state, state)
      state
    end
  end

  defp enter(%{game_state: game_state} = state, gid) do
    %{
      state
      | game_state: %{game_state | inside_npc_areas: MapSet.put(game_state.inside_npc_areas, gid)}
    }
  end

  defp still_inside?(gid, game_state) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} ->
        Placement.touch_area_contains?(placement, game_state.map_name, game_state.x, game_state.y)

      :error ->
        false
    end
  end

  defp release_claim(gid, game_state) do
    if Touch.release(gid, game_state.character_id) == :released,
      do: hand_off(gid, MapSet.new([game_state.character_id]))
  end

  # The sender side of a handoff: the first player in the area whose registry
  # snapshot is eligible gets the cast; the receiver re-validates.
  defp hand_off(gid, excluded) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, %Placement{trigger: {xs, ys}} = placement}} ->
        placement.map
        |> SpatialIndex.get_players_in_area(
          placement.x - xs,
          placement.y - ys,
          placement.x + xs,
          placement.y + ys
        )
        |> Enum.reject(&MapSet.member?(excluded, &1))
        |> Enum.find_value(&eligible_pid/1)
        |> case do
          nil -> :ok
          pid -> PlayerSession.touch_handoff(pid, gid, excluded)
        end

      _no_area ->
        :ok
    end
  end

  defp eligible_pid(char_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{} = snapshot, pid}} when is_pid(pid) ->
        if eligible?(snapshot), do: pid

      _gone ->
        nil
    end
  end

  defp eligible?(game_state) do
    is_nil(game_state.pending_map_load) and game_state.action_state != :dead and
      not Concealment.unit_concealed?(:player, game_state.character_id)
  end

  defp warps_for_map(map) do
    case Warps.for_map(map) do
      {:ok, list} -> list
      :error -> []
    end
  end
end
