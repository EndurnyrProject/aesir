defmodule Aesir.ZoneServer.Unit.SpatialIndexTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup do
    SpatialIndex.init()

    on_exit(fn ->
      if :ets.info(:spatial_index) != :undefined do
        :ets.delete_all_objects(:spatial_index)
      end

      if :ets.info(:player_positions) != :undefined do
        :ets.delete_all_objects(:player_positions)
      end
    end)

    :ok
  end

  describe "init/0" do
    test "creates required ETS tables" do
      assert :ets.info(:spatial_index) != :undefined
      assert :ets.info(:player_positions) != :undefined
    end

    test "handles multiple init calls gracefully" do
      assert SpatialIndex.init() == :ok
      assert SpatialIndex.init() == :ok
    end
  end

  describe "add_player/4" do
    test "adds a player to the spatial index" do
      assert SpatialIndex.add_player(150_000, 100, 100, "prontera") == :ok

      cell_x = div(100, 8)
      cell_y = div(100, 8)

      assert [{{"prontera", 12, 12}, players}] =
               :ets.lookup(:spatial_index, {"prontera", cell_x, cell_y})

      assert MapSet.member?(players, 150_000)
    end

    test "adds player position to player_positions table" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")

      assert [{150_000, {"prontera", 100, 100}}] = :ets.lookup(:player_positions, 150_000)
    end

    test "handles multiple players in same cell" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")
      SpatialIndex.add_player(150_001, 101, 101, "prontera")

      cell_x = div(100, 8)
      cell_y = div(100, 8)

      [{_, players}] = :ets.lookup(:spatial_index, {"prontera", cell_x, cell_y})
      assert MapSet.size(players) == 2
      assert MapSet.member?(players, 150_000)
      assert MapSet.member?(players, 150_001)
    end

    test "handles players in different maps" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")
      SpatialIndex.add_player(150_001, 100, 100, "geffen")

      cell_x = div(100, 8)
      cell_y = div(100, 8)

      [{_, prontera_players}] = :ets.lookup(:spatial_index, {"prontera", cell_x, cell_y})
      [{_, geffen_players}] = :ets.lookup(:spatial_index, {"geffen", cell_x, cell_y})

      assert MapSet.member?(prontera_players, 150_000)
      assert MapSet.member?(geffen_players, 150_001)
    end

    test "handles edge coordinates at cell boundaries" do
      SpatialIndex.add_player(150_000, 0, 0, "prontera")
      SpatialIndex.add_player(150_001, 7, 7, "prontera")
      SpatialIndex.add_player(150_002, 8, 8, "prontera")

      [{_, cell_00_players}] = :ets.lookup(:spatial_index, {"prontera", 0, 0})
      [{_, cell_11_players}] = :ets.lookup(:spatial_index, {"prontera", 1, 1})

      assert MapSet.size(cell_00_players) == 2
      assert MapSet.member?(cell_00_players, 150_000)
      assert MapSet.member?(cell_00_players, 150_001)

      assert MapSet.size(cell_11_players) == 1
      assert MapSet.member?(cell_11_players, 150_002)
    end
  end

  describe "update_position/4" do
    test "moves player to new position in same cell" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")
      SpatialIndex.update_position(150_000, 101, 101, "prontera")

      cell_x = div(100, 8)
      cell_y = div(100, 8)

      [{_, players}] = :ets.lookup(:spatial_index, {"prontera", cell_x, cell_y})
      assert MapSet.member?(players, 150_000)

      [{150_000, {"prontera", 101, 101}}] = :ets.lookup(:player_positions, 150_000)
    end

    test "moves player to different cell" do
      SpatialIndex.add_player(150_000, 7, 7, "prontera")
      SpatialIndex.update_position(150_000, 8, 8, "prontera")

      old_cell = :ets.lookup(:spatial_index, {"prontera", 0, 0})

      case old_cell do
        [] -> assert true
        [{_, players}] -> assert MapSet.size(players) == 0
      end

      [{_, new_players}] = :ets.lookup(:spatial_index, {"prontera", 1, 1})
      assert MapSet.member?(new_players, 150_000)
    end

    test "handles non-existent player gracefully" do
      assert SpatialIndex.update_position(999_999, 100, 100, "prontera") == :ok
    end

    test "handles map change" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")
      SpatialIndex.update_position(150_000, 50, 50, "geffen")

      prontera_lookup = :ets.lookup(:spatial_index, {"prontera", 12, 12})

      case prontera_lookup do
        [] -> assert true
        [{_, players}] -> assert not MapSet.member?(players, 150_000)
      end

      [{_, geffen_players}] = :ets.lookup(:spatial_index, {"geffen", 6, 6})
      assert MapSet.member?(geffen_players, 150_000)

      [{150_000, {"geffen", 50, 50}}] = :ets.lookup(:player_positions, 150_000)
    end
  end

  describe "remove_player/1" do
    test "removes player from spatial index" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")
      SpatialIndex.remove_player(150_000)

      cell_x = div(100, 8)
      cell_y = div(100, 8)

      lookup = :ets.lookup(:spatial_index, {"prontera", cell_x, cell_y})

      case lookup do
        [] -> assert true
        [{_, players}] -> assert not MapSet.member?(players, 150_000)
      end
    end

    test "removes player position record" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")
      SpatialIndex.remove_player(150_000)

      assert :ets.lookup(:player_positions, 150_000) == []
    end

    test "handles non-existent player gracefully" do
      assert SpatialIndex.remove_player(999_999) == :ok
    end

    test "handles multiple removals gracefully" do
      SpatialIndex.add_player(150_000, 100, 100, "prontera")

      assert SpatialIndex.remove_player(150_000) == :ok
      assert SpatialIndex.remove_player(150_000) == :ok
    end
  end

  describe "get_players_in_range/4" do
    setup do
      # Create a grid of players for testing
      # Using 8x8 cells, place players strategically
      players = [
        # Cell (6, 6)
        {150_000, 50, 50},
        # Cell (6, 6) - same cell
        {150_001, 55, 55},
        # Cell (7, 7) - adjacent cell
        {150_002, 58, 58},
        # Cell (12, 12) - far away
        {150_003, 100, 100},
        # Cell (5, 5) - diagonal adjacent
        {150_004, 42, 42},
        # Cell (8, 8) - 2 cells away
        {150_005, 66, 66},
        # Cell (6, 6) - same cell as center
        {150_006, 51, 51}
      ]

      Enum.each(players, fn {id, x, y} ->
        SpatialIndex.add_player(id, x, y, "prontera")
      end)

      {:ok, players: players}
    end

    test "finds players within small range", %{players: _players} do
      # Range of 5 from (50, 50) should find only close players
      # Using Manhattan distance: |x2-x1| + |y2-y1|
      result = SpatialIndex.get_players_in_range("prontera", 50, 50, 5)

      # Should find players within Manhattan distance of 5
      # Distance 0 (50,50)
      assert 150_000 in result
      # Distance 2 (51,51)
      assert 150_006 in result
      # Distance 10 (55,55)
      assert 150_001 not in result
      # Distance 16 (58,58)
      assert 150_002 not in result
      # Distance 100 (100,100)
      assert 150_003 not in result
    end

    test "finds players within medium range", %{players: _players} do
      # Range of 10 from (50, 50) using Manhattan distance
      result = SpatialIndex.get_players_in_range("prontera", 50, 50, 10)

      # Distance 0 (50,50)
      assert 150_000 in result
      # Distance 10 (55,55)
      assert 150_001 in result
      # Distance 2 (51,51)
      assert 150_006 in result
      # Distance 16 (58,58)
      assert 150_002 not in result
      # Distance 16 (42,42)
      assert 150_004 not in result
      # Distance 100 (100,100)
      assert 150_003 not in result
    end

    test "finds players within large range", %{players: _players} do
      # Range of 20 from (50, 50) using Manhattan distance
      result = SpatialIndex.get_players_in_range("prontera", 50, 50, 20)

      # Distance 0 (50,50)
      assert 150_000 in result
      # Distance 10 (55,55)
      assert 150_001 in result
      # Distance 16 (58,58)
      assert 150_002 in result
      # Distance 16 (42,42)
      assert 150_004 in result
      # Distance 2 (51,51)
      assert 150_006 in result
      # Distance 100 (100,100)
      assert 150_003 not in result
      # Distance 32 (66,66)
      assert 150_005 not in result
    end

    test "returns empty list for empty map" do
      result = SpatialIndex.get_players_in_range("empty_map", 50, 50, 10)
      assert result == []
    end

    test "handles different maps correctly" do
      SpatialIndex.add_player(150_007, 50, 50, "geffen")

      prontera_result = SpatialIndex.get_players_in_range("prontera", 50, 50, 5)
      geffen_result = SpatialIndex.get_players_in_range("geffen", 50, 50, 5)

      assert 150_000 in prontera_result
      assert 150_007 not in prontera_result

      assert 150_007 in geffen_result
      assert 150_000 not in geffen_result
    end

    test "handles edge case at map origin" do
      SpatialIndex.add_player(150_010, 0, 0, "prontera")
      SpatialIndex.add_player(150_011, 5, 5, "prontera")

      result = SpatialIndex.get_players_in_range("prontera", 0, 0, 10)

      assert 150_010 in result
      assert 150_011 in result
    end

    test "excludes players exactly at range boundary" do
      SpatialIndex.add_player(150_020, 60, 50, "prontera")

      result = SpatialIndex.get_players_in_range("prontera", 50, 50, 9)
      assert 150_020 not in result

      result = SpatialIndex.get_players_in_range("prontera", 50, 50, 10)
      assert 150_020 in result
    end
  end

  describe "get_players_in_cell/3" do
    test "returns players in specific cell" do
      SpatialIndex.add_player(150_000, 50, 50, "prontera")
      SpatialIndex.add_player(150_001, 55, 55, "prontera")
      SpatialIndex.add_player(150_002, 58, 58, "prontera")

      result = SpatialIndex.get_players_in_cell("prontera", 6, 6)

      assert 150_000 in result
      assert 150_001 in result
      assert 150_002 not in result
    end

    test "returns empty list for empty cell" do
      result = SpatialIndex.get_players_in_cell("prontera", 0, 0)
      assert result == []
    end

    test "handles different maps correctly" do
      SpatialIndex.add_player(150_000, 50, 50, "prontera")
      SpatialIndex.add_player(150_001, 50, 50, "geffen")

      prontera_result = SpatialIndex.get_players_in_cell("prontera", 6, 6)
      geffen_result = SpatialIndex.get_players_in_cell("geffen", 6, 6)

      assert 150_000 in prontera_result
      assert 150_001 not in prontera_result

      assert 150_001 in geffen_result
      assert 150_000 not in geffen_result
    end
  end

  describe "stress testing" do
    test "handles large number of players" do
      for id <- 150_000..150_999 do
        x = :rand.uniform(500)
        y = :rand.uniform(500)
        SpatialIndex.add_player(id, x, y, "prontera")
      end

      result = SpatialIndex.get_players_in_range("prontera", 250, 250, 20)
      assert is_list(result)
    end

    test "handles rapid position updates" do
      SpatialIndex.add_player(150_000, 50, 50, "prontera")

      for _ <- 1..100 do
        x = 50 + :rand.uniform(10) - 5
        y = 50 + :rand.uniform(10) - 5
        SpatialIndex.update_position(150_000, x, y, "prontera")
      end

      [{150_000, {"prontera", final_x, final_y}}] = :ets.lookup(:player_positions, 150_000)
      assert final_x >= 45 and final_x <= 55
      assert final_y >= 45 and final_y <= 55
    end

    test "handles concurrent operations" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            player_id = 150_000 + i

            SpatialIndex.add_player(player_id, i * 10, i * 10, "prontera")

            for j <- 1..10 do
              SpatialIndex.update_position(player_id, i * 10 + j, i * 10 + j, "prontera")
            end

            SpatialIndex.get_players_in_range("prontera", i * 10, i * 10, 15)
            SpatialIndex.remove_player(player_id)
          end)
        end

      results = Task.await_many(tasks)
      assert length(results) == 10
    end
  end
end
