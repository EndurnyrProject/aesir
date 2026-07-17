defmodule Aesir.ZoneServer.Integration.WarpTest do
  @moduledoc """
  End-to-end cross-map warp handshake: `WarpHandler.warp` tears the player down
  on its current map and asks the client to load the destination via `MapMove`;
  the client's follow-up `MapLoaded` respawns the player on the new map without
  re-syncing inventory/skills.

  Drives the real `WarpHandler` -> `PacketHandler.handle_map_loaded` path; only
  the I/O collaborators (map cache, spatial index, registry, broadcast) are
  stubbed.
  """
  use ExUnit.Case, async: true

  @moduletag :integration
  import Mimic

  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MapMove
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defp session_state do
    game_state = %PlayerState{
      character_id: 1000,
      account_id: 2000,
      character_name: "Wanderer",
      map_name: "prontera",
      x: 150,
      y: 150,
      action_state: :idle,
      movement_state: :standing,
      movement_intent: :none,
      walk_path: [],
      view_range: 14,
      visible_players: MapSet.new([2001]),
      visible_mobs: MapSet.new()
    }

    %{game_state: game_state, connection_pid: self()}
  end

  test "warp then MapLoaded relocates the player and respawns without a resync" do
    stub(MapCache, :get, fn "geffen" -> {:ok, %MapData{name: "geffen"}} end)
    stub(MapData, :walkable?, fn _map, 100, 120 -> true end)
    stub(SpatialIndex, :get_visible_players, fn 1000 -> [2001] end)
    stub(SpatialIndex, :remove_player, fn 1000 -> :ok end)
    stub(SpatialIndex, :clear_visibility, fn 1000 -> :ok end)
    stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)
    stub(Broadcast, :subscribe_mob_despawns, fn _map -> :ok end)
    stub(Broadcast, :unsubscribe_mob_despawns, fn _map -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)

    assert {:ok, warped_state} = WarpHandler.warp(session_state(), "geffen", 100, 120)

    assert warped_state.game_state.map_name == "geffen"
    assert warped_state.game_state.pending_map_load == :warp
    assert_received {:send, :control, {:map_move, %MapMove{map_name: "geffen", x: 100, y: 120}}}

    assert {:noreply, final_state} = PacketHandler.handle_message(%MapLoaded{}, warped_state)

    assert final_state.game_state.pending_map_load == nil
    assert final_state.game_state.map_name == "geffen"
    assert final_state.game_state.x == 100
    assert final_state.game_state.y == 120
    assert_received :respawn_after_warp
    refute_received {:send, :bulk, _}
  end
end
