defmodule Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler do
  @moduledoc """
  Cross-map warp: relocates a player from one map to another within the same
  zone server.

  A warp tears the player down on its current map (vanish to observers, drop it
  from the spatial index), swaps `PlayerState` to the destination, and tells the
  client to load the new map via `MapMove`. The player re-enters the world when
  the client re-acks `MapLoaded`, which re-runs the normal spawn flow on the
  destination map (see `MapLoadHandler.handle_map_loaded/1`).

  `leave_current_map/2` is the shared teardown also used by the disconnect path.
  """
  require Logger

  alias Aesir.Net.MapMove
  alias Aesir.Net.UnitDespawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @type session_state :: %{
          required(:game_state) => PlayerState.t(),
          required(:connection_pid) => pid(),
          optional(atom()) => any()
        }

  @fallback_radius 5

  @doc """
  Warps the player to `(dest_map, dest_x, dest_y)`.

  If the destination cell is blocked, a spiral search for the nearest walkable
  cell within `#{@fallback_radius}` (Chebyshev distance) is attempted; the
  warp rewrites to that cell on hit. Real warp data and save-point respawn
  occasionally target a slightly-off cell. When no walkable cell is found the
  warp still proceeds to the requested cell.

  Returns `{:ok, new_state}` with the player relocated and a `MapMove` sent, or
  `{:error, :map_not_found}` leaving the session untouched. An open storage
  window is force-closed only on a cross-map warp (design "Storage window
  lifecycle": it stays open across same-map movement); a same-map warp (e.g.
  `AL_TELEPORT` level 1) leaves it untouched.
  """
  @spec warp(session_state(), String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, session_state()} | {:error, :map_not_found}
  def warp(%{game_state: game_state, connection_pid: connection_pid} = state, dest_map, x, y) do
    dest_map = normalize_map(dest_map)
    same_map? = dest_map == game_state.map_name

    with {:ok, map_data} <- fetch_map(dest_map),
         {:ok, {fx, fy}} <- ensure_walkable(map_data, x, y) do
      leave_current_map(game_state, DespawnReason.teleport())
      Broadcast.unsubscribe_mob_despawns(game_state.map_name)
      Broadcast.subscribe_mob_despawns(dest_map)

      new_game_state =
        game_state
        |> PlayerState.relocate(dest_map, fx, fy)
        |> Map.put(:pending_map_load, :warp)
        |> close_storage_on_cross_map(same_map?)

      state = StateCommit.commit(state, new_game_state)
      MessageRouter.send_to(connection_pid, %MapMove{map_name: dest_map, x: fx, y: fy})

      Logger.debug(
        "Player #{game_state.character_id} warping #{game_state.map_name} -> #{dest_map} (#{fx}, #{fy})"
      )

      {:ok, state}
    end
  end

  @doc """
  Drops the player from its current map: vanishes it for every observer with the
  given despawn `reason`, removes it from the spatial index and clears its
  visibility pairs. Shared by the warp and disconnect paths.
  """
  @spec leave_current_map(PlayerState.t(), non_neg_integer()) :: :ok
  def leave_current_map(%PlayerState{character_id: char_id} = _game_state, reason) do
    vanish = %UnitDespawn{gid: char_id, reason: reason}

    char_id
    |> SpatialIndex.get_visible_players()
    |> Broadcast.to_players(vanish, exclude_id: char_id)

    SpatialIndex.remove_player(char_id)
    SpatialIndex.clear_visibility(char_id)
    :ok
  end

  @spec close_storage_on_cross_map(PlayerState.t(), boolean()) :: PlayerState.t()
  defp close_storage_on_cross_map(game_state, true), do: game_state
  defp close_storage_on_cross_map(game_state, false), do: %{game_state | storage: nil}

  defp fetch_map(map_name) do
    with {:error, :not_found} <- MapCache.get(map_name) do
      {:error, :map_not_found}
    end
  end

  defp ensure_walkable(map_data, x, y) do
    if MapData.walkable?(map_data, x, y) do
      {:ok, {x, y}}
    else
      case nearest_walkable(map_data, x, y) do
        {nx, ny} -> {:ok, {nx, ny}}
        nil -> {:ok, {x, y}}
      end
    end
  end

  @spec nearest_walkable(MapData.t(), integer(), integer()) ::
          {integer(), integer()} | nil
  defp nearest_walkable(map_data, x, y) do
    Enum.find_value(1..@fallback_radius, fn radius ->
      Enum.find(ring_cells(x, y, radius), fn {cx, cy} ->
        MapData.walkable?(map_data, cx, cy)
      end)
    end)
  end

  @spec ring_cells(integer(), integer(), pos_integer()) :: [{integer(), integer()}]
  defp ring_cells(x, y, radius) do
    for dy <- -radius..radius,
        dx <- -radius..radius,
        max(abs(dx), abs(dy)) == radius do
      {x + dx, y + dy}
    end
  end

  # Player map names are canonically stored without the ".gat" suffix (matching
  # the map cache / coordinator keys); save points and other rAthena-sourced
  # names may still carry it.
  defp normalize_map(map_name), do: String.replace_suffix(map_name, ".gat", "")
end
