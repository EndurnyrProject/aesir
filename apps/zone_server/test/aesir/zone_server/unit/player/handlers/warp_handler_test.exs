defmodule Aesir.ZoneServer.Unit.Player.Handlers.WarpHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.MapMove
  alias Aesir.Net.UnitDespawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defp state do
    game_state = %PlayerState{
      character_id: 1000,
      account_id: 2000,
      character_name: "Gm",
      map_name: "prontera",
      x: 150,
      y: 150,
      dir: 0,
      action_state: :moving,
      movement_state: :moving,
      movement_intent: :combat,
      walk_path: [{151, 151}, {152, 152}],
      combat_target_id: 42,
      visible_players: MapSet.new([2001]),
      visible_mobs: MapSet.new([9001]),
      last_visibility_cell: {18, 18}
    }

    %{game_state: game_state, connection_pid: self()}
  end

  defp stub_teardown do
    stub(SpatialIndex, :get_visible_players, fn 1000 -> [2001] end)
    stub(SpatialIndex, :remove_player, fn 1000 -> :ok end)
    stub(SpatialIndex, :clear_visibility, fn 1000 -> :ok end)
    stub(Broadcast, :subscribe_mob_despawns, fn _map -> :ok end)
    stub(Broadcast, :unsubscribe_mob_despawns, fn _map -> :ok end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
  end

  describe "warp/4 validation" do
    test "unknown destination map returns :map_not_found and leaves the session untouched" do
      stub(MapCache, :get, fn "nowhere" -> {:error, :not_found} end)
      reject(&SpatialIndex.remove_player/1)

      assert {:error, :map_not_found} = WarpHandler.warp(state(), "nowhere", 100, 120)
      refute_received {:send, :control, {:map_move, _}}
    end

    test "non-walkable destination with no walkable neighbour still warps to the requested cell" do
      stub(MapCache, :get, fn "geffen" -> {:ok, %MapData{name: "geffen"}} end)
      stub(MapData, :walkable?, fn _, _, _ -> false end)
      stub_teardown()
      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, %{game_state: gs}} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert gs.x == 100
      assert gs.y == 120
      assert_received {:send, :control, {:map_move, %MapMove{map_name: "geffen", x: 100, y: 120}}}
    end
  end

  describe "warp/4 destination walkable fallback" do
    setup do
      stub(MapCache, :get, fn "geffen" -> {:ok, %MapData{name: "geffen"}} end)
      stub_teardown()
      :ok
    end

    test "blocked destination with a walkable neighbour at radius 1 rewrites to it and succeeds" do
      stub(MapData, :walkable?, fn
        _, 100, 120 -> false
        _, 101, 120 -> true
        _, _, _ -> false
      end)

      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, %{game_state: gs}} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert gs.x == 101
      assert gs.y == 120

      assert_received {:send, :control, {:map_move, %MapMove{map_name: "geffen", x: 101, y: 120}}}
    end

    test "blocked destination with a walkable neighbour at radius 5 (search edge) rewrites and succeeds" do
      stub(MapData, :walkable?, fn
        _, 100, 120 -> false
        _, 105, 125 -> true
        _, _, _ -> false
      end)

      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, %{game_state: gs}} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert gs.x == 105
      assert gs.y == 125

      assert_received {:send, :control, {:map_move, %MapMove{map_name: "geffen", x: 105, y: 125}}}
    end

    test "destination blocked beyond radius 5 falls back to the requested cell and succeeds" do
      stub(MapData, :walkable?, fn _, _, _ -> false end)
      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, %{game_state: gs}} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert gs.x == 100
      assert gs.y == 120
      assert_received {:send, :control, {:map_move, %MapMove{map_name: "geffen", x: 100, y: 120}}}
    end

    test "walkable destination is unchanged — fallback search is not invoked" do
      expect(MapData, :walkable?, 1, fn _, 100, 120 -> true end)
      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, %{game_state: gs}} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert gs.x == 100
      assert gs.y == 120
    end
  end

  describe "warp/4 success" do
    setup do
      stub(MapCache, :get, fn "geffen" -> {:ok, %MapData{name: "geffen"}} end)
      stub(MapData, :walkable?, fn _map, 100, 120 -> true end)
      stub_teardown()
      :ok
    end

    test "vanishes the player for observers with the teleport reason" do
      expect(Broadcast, :to_players, fn visible, %UnitDespawn{gid: 1000, reason: reason}, opts ->
        send(self(), {:vanished, visible, reason, opts})
        :ok
      end)

      assert {:ok, _new_state} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert_received {:vanished, [2001], reason, opts}
      assert reason == DespawnReason.teleport()
      assert opts[:exclude_id] == 1000
    end

    test "relocates the player and resets transient movement/combat/visibility state" do
      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, %{game_state: gs}} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert gs.map_name == "geffen"
      assert gs.x == 100
      assert gs.y == 120
      assert gs.pending_map_load == :warp
      assert gs.action_state == :idle
      assert gs.walk_path == []
      assert gs.movement_state == :standing
      assert gs.combat_target_id == nil
      assert gs.visible_players == MapSet.new()
      assert gs.visible_mobs == MapSet.new()
      assert gs.last_visibility_cell == nil
    end

    test "swaps the per-map mob-despawn subscription" do
      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      expect(Broadcast, :unsubscribe_mob_despawns, fn "prontera" -> :ok end)
      expect(Broadcast, :subscribe_mob_despawns, fn "geffen" -> :ok end)

      assert {:ok, _} = WarpHandler.warp(state(), "geffen", 100, 120)
    end

    test "sends a MapMove on the control channel" do
      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, _} = WarpHandler.warp(state(), "geffen", 100, 120)

      assert_received {:send, :control, {:map_move, %MapMove{map_name: "geffen", x: 100, y: 120}}}
    end

    test "strips a .gat suffix from the destination map name" do
      stub(Broadcast, :to_players, fn _visible, _packet, _opts -> :ok end)

      assert {:ok, %{game_state: gs}} = WarpHandler.warp(state(), "geffen.gat", 100, 120)

      assert gs.map_name == "geffen"
      assert_received {:send, :control, {:map_move, %MapMove{map_name: "geffen"}}}
    end
  end

  describe "leave_current_map/2" do
    test "vanishes observers, removes from the index and clears visibility" do
      expect(SpatialIndex, :get_visible_players, fn 1000 -> [2001, 2002] end)
      expect(SpatialIndex, :remove_player, fn 1000 -> :ok end)
      expect(SpatialIndex, :clear_visibility, fn 1000 -> :ok end)

      expect(Broadcast, :to_players, fn [2001, 2002], %UnitDespawn{gid: 1000, reason: 2}, opts ->
        assert opts[:exclude_id] == 1000
        :ok
      end)

      assert :ok =
               WarpHandler.leave_current_map(
                 state().game_state,
                 DespawnReason.logged_out()
               )
    end
  end
end
