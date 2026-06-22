defmodule Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler do
  @moduledoc """
  Cross-map warp: relocates a player from one map to another within the same
  zone server.

  A warp tears the player down on its current map (vanish to observers, drop it
  from the spatial index), swaps `PlayerState` to the destination, and tells the
  client to load the new map via `MapMove`. The player re-enters the world when
  the client re-acks `MapLoaded`, which re-runs the normal spawn flow on the
  destination map (see `PacketHandler.handle_map_loaded/1`).

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
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type session_state :: %{
          required(:game_state) => PlayerState.t(),
          required(:connection_pid) => pid(),
          optional(atom()) => any()
        }

  @doc """
  Warps the player to `(dest_map, dest_x, dest_y)`.

  Returns `{:ok, new_state}` with the player relocated and a `MapMove` sent, or
  `{:error, :map_not_found | :cell_blocked}` leaving the session untouched.
  """
  @spec warp(session_state(), String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, session_state()} | {:error, :map_not_found | :cell_blocked}
  def warp(%{game_state: game_state, connection_pid: connection_pid} = state, dest_map, x, y) do
    dest_map = normalize_map(dest_map)

    with {:ok, map_data} <- fetch_map(dest_map),
         :ok <- ensure_walkable(map_data, x, y) do
      leave_current_map(game_state, DespawnReason.teleport())
      Broadcast.unsubscribe_mob_despawns(game_state.map_name)
      Broadcast.subscribe_mob_despawns(dest_map)

      new_game_state =
        game_state
        |> PlayerState.relocate(dest_map, x, y)
        |> Map.put(:pending_map_load, :warp)

      UnitRegistry.update_unit_state(:player, new_game_state.character_id, new_game_state)
      MessageRouter.send_to(connection_pid, %MapMove{map_name: dest_map, x: x, y: y})

      Logger.debug(
        "Player #{game_state.character_id} warping #{game_state.map_name} -> #{dest_map} (#{x}, #{y})"
      )

      {:ok, %{state | game_state: new_game_state}}
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

  defp fetch_map(map_name) do
    with {:error, :not_found} <- MapCache.get(map_name) do
      {:error, :map_not_found}
    end
  end

  defp ensure_walkable(map_data, x, y) do
    if MapData.walkable?(map_data, x, y), do: :ok, else: {:error, :cell_blocked}
  end

  # Player map names are canonically stored without the ".gat" suffix (matching
  # the map cache / coordinator keys); save points and other rAthena-sourced
  # names may still carry it.
  defp normalize_map(map_name), do: String.replace_suffix(map_name, ".gat", "")
end
