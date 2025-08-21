defmodule Aesir.ZoneServer.Unit.SpatialIndexTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :setup_ets_tables

  describe "visibility range" do
    test "players within 14 cells can see each other" do
      # Add player 1 at position (50, 50)
      player1_id = 1001
      SpatialIndex.add_player(player1_id, 50, 50, "prontera")

      # Add player 2 at position (60, 50) - 10 cells away (within range)
      player2_id = 1002
      SpatialIndex.add_player(player2_id, 60, 50, "prontera")

      # Update visibility
      SpatialIndex.update_visibility(player1_id, player2_id, true)

      # Check bidirectional visibility
      assert SpatialIndex.can_see?(player1_id, player2_id)
      assert SpatialIndex.can_see?(player2_id, player1_id)

      # Check get_visible_players
      assert player2_id in SpatialIndex.get_visible_players(player1_id)
      assert player1_id in SpatialIndex.get_visible_players(player2_id)
    end

    test "players beyond 14 cells cannot see each other" do
      # Add player 1 at position (50, 50)
      player1_id = 1001
      SpatialIndex.add_player(player1_id, 50, 50, "prontera")

      # Add player 2 at position (70, 50) - 20 cells away (out of range)
      player2_id = 1002
      SpatialIndex.add_player(player2_id, 70, 50, "prontera")

      # Visibility should not be set for out-of-range players
      refute SpatialIndex.can_see?(player1_id, player2_id)
      refute SpatialIndex.can_see?(player2_id, player1_id)

      # Verify they're not in visible lists
      refute player2_id in SpatialIndex.get_visible_players(player1_id)
      refute player1_id in SpatialIndex.get_visible_players(player2_id)
    end

    test "diagonal distance calculation respects 14 cell range" do
      # Add player 1 at position (50, 50)
      player1_id = 1001
      SpatialIndex.add_player(player1_id, 50, 50, "prontera")

      # Add player 2 at diagonal position (57, 57) - 14 cells Manhattan distance
      player2_id = 1002
      SpatialIndex.add_player(player2_id, 57, 57, "prontera")

      # Update visibility
      SpatialIndex.update_visibility(player1_id, player2_id, true)

      # Should be visible (14 cells Manhattan distance)
      assert SpatialIndex.can_see?(player1_id, player2_id)
      assert SpatialIndex.can_see?(player2_id, player1_id)
    end

    test "get_players_in_range returns correct players" do
      # Add multiple players
      SpatialIndex.add_player(1001, 50, 50, "prontera")
      # 5 cells away
      SpatialIndex.add_player(1002, 55, 50, "prontera")
      # 10 cells away
      SpatialIndex.add_player(1003, 60, 50, "prontera")
      # 15 cells away
      SpatialIndex.add_player(1004, 65, 50, "prontera")
      # 30 cells away
      SpatialIndex.add_player(1005, 80, 50, "prontera")

      # Get players within 14 cells of position (50, 50)
      players_in_range = SpatialIndex.get_players_in_range("prontera", 50, 50, 14)

      # Should include players within 14 cells
      # Self
      assert 1001 in players_in_range
      # 5 cells
      assert 1002 in players_in_range
      # 10 cells
      assert 1003 in players_in_range
      # 15 cells (out of range)
      refute 1004 in players_in_range
      # 30 cells (out of range)
      refute 1005 in players_in_range
    end

    test "visibility updates when player moves" do
      # Add two players initially in range
      player1_id = 1001
      player2_id = 1002
      SpatialIndex.add_player(player1_id, 50, 50, "prontera")
      SpatialIndex.add_player(player2_id, 55, 50, "prontera")

      # Set initial visibility
      SpatialIndex.update_visibility(player1_id, player2_id, true)
      assert SpatialIndex.can_see?(player1_id, player2_id)

      # Move player2 out of range
      SpatialIndex.update_position(player2_id, 70, 50, "prontera")

      # Update visibility to false (out of range)
      SpatialIndex.update_visibility(player1_id, player2_id, false)

      # Verify visibility is removed
      refute SpatialIndex.can_see?(player1_id, player2_id)
      refute SpatialIndex.can_see?(player2_id, player1_id)
    end

    test "clear_visibility removes all visibility pairs" do
      player1_id = 1001
      SpatialIndex.add_player(player1_id, 50, 50, "prontera")

      # Add multiple visible players
      for i <- 2..5 do
        player_id = 1000 + i
        SpatialIndex.add_player(player_id, 50 + i, 50, "prontera")
        SpatialIndex.update_visibility(player1_id, player_id, true)
      end

      # Verify all are visible
      visible_before = SpatialIndex.get_visible_players(player1_id)
      assert length(visible_before) == 4

      # Clear visibility for player1
      SpatialIndex.clear_visibility(player1_id)

      # Verify no players are visible
      visible_after = SpatialIndex.get_visible_players(player1_id)
      assert visible_after == []

      # Verify bidirectional removal
      for i <- 2..5 do
        player_id = 1000 + i
        refute SpatialIndex.can_see?(player_id, player1_id)
      end
    end

    test "players on different maps cannot see each other" do
      # Add players on different maps
      player1_id = 1001
      player2_id = 1002
      SpatialIndex.add_player(player1_id, 50, 50, "prontera")
      # Same coords, different map
      SpatialIndex.add_player(player2_id, 50, 50, "geffen")

      # Get players in range should not include other maps
      prontera_players = SpatialIndex.get_players_in_range("prontera", 50, 50, 14)
      geffen_players = SpatialIndex.get_players_in_range("geffen", 50, 50, 14)

      assert player1_id in prontera_players
      refute player2_id in prontera_players

      assert player2_id in geffen_players
      refute player1_id in geffen_players
    end
  end

  describe "spatial index grid cells" do
    test "players in same cell are efficiently retrieved" do
      # Add multiple players in same 8x8 cell
      for i <- 0..7 do
        SpatialIndex.add_player(1000 + i, i, i, "prontera")
      end

      # All should be in cell (0, 0)
      players_in_cell = SpatialIndex.get_players_in_cell("prontera", 0, 0)
      assert length(players_in_cell) == 8
    end

    test "players in adjacent cells are included in range queries" do
      # Add player at cell boundary
      # End of cell (0,0)
      SpatialIndex.add_player(1001, 7, 7, "prontera")
      # Start of cell (1,1)
      SpatialIndex.add_player(1002, 8, 8, "prontera")

      # Both should be found when searching from (7,7)
      players = SpatialIndex.get_players_in_range("prontera", 7, 7, 2)
      assert 1001 in players
      assert 1002 in players
    end
  end
end
