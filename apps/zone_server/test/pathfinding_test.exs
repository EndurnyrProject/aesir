defmodule Aesir.ZoneServer.PathfindingTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Pathfinding

  describe "find_path/3" do
    setup :setup_ets_tables

    setup do
      map_data = MapData.new("test_map", 10, 10)
      :ets.insert(EtsTable.table_for(:map_cache), {"test_map", map_data})
      {:ok, map_data: map_data}
    end

    test "returns empty path when start equals goal", %{map_data: map_data} do
      assert {:ok, []} = Pathfinding.find_path(map_data, {5, 5}, {5, 5})
    end

    test "finds straight horizontal path", %{map_data: map_data} do
      assert {:ok, path} = Pathfinding.find_path(map_data, {0, 5}, {5, 5})
      assert [{1, 5}, {2, 5}, {3, 5}, {4, 5}, {5, 5}] = path
    end

    test "finds straight vertical path", %{map_data: map_data} do
      assert {:ok, path} = Pathfinding.find_path(map_data, {5, 0}, {5, 5})
      assert [{5, 1}, {5, 2}, {5, 3}, {5, 4}, {5, 5}] = path
    end

    test "finds diagonal path", %{map_data: map_data} do
      assert {:ok, path} = Pathfinding.find_path(map_data, {0, 0}, {5, 5})

      assert length(path) == 5
      assert List.last(path) == {5, 5}
    end

    test "returns error for invalid start position", %{map_data: map_data} do
      assert {:error, :invalid_start} = Pathfinding.find_path(map_data, {-1, 5}, {5, 5})
      assert {:error, :invalid_start} = Pathfinding.find_path(map_data, {10, 5}, {5, 5})
    end

    test "returns error for invalid goal position", %{map_data: map_data} do
      assert {:error, :invalid_goal} = Pathfinding.find_path(map_data, {5, 5}, {-1, 5})
      assert {:error, :invalid_goal} = Pathfinding.find_path(map_data, {5, 5}, {5, 10})
    end

    test "finds path around obstacle", %{map_data: map_data} do
      # Create a wall that blocks the direct path
      map_data =
        map_data
        |> MapData.set_cell(4, 5, GatType.wall())
        |> MapData.set_cell(5, 5, GatType.wall())
        |> MapData.set_cell(6, 5, GatType.wall())

      cache(map_data)

      assert {:ok, path} = Pathfinding.find_path(map_data, {0, 5}, {9, 5})

      # Path should go around the wall (above or below)
      # At least as long as direct path
      assert length(path) >= 9
      assert List.last(path) == {9, 5}

      # Verify path doesn't go through wall
      refute Enum.any?(path, fn {x, y} -> y == 5 and x in [4, 5, 6] end)
    end

    test "does not cut diagonally through a diagonal wall", %{map_data: map_data} do
      # A diagonal Ice Wall: dynamic movement blockers on (4,4), (5,5), (6,6).
      :ok = Cell.put("test_map", 4, 4, :skill_unit, 1, blocks_movement: true)
      :ok = Cell.put("test_map", 5, 5, :skill_unit, 2, blocks_movement: true)
      :ok = Cell.put("test_map", 6, 6, :skill_unit, 3, blocks_movement: true)

      assert {:ok, path} = Pathfinding.find_path(map_data, {5, 4}, {5, 6})

      refute Enum.any?(path, &(&1 in [{4, 4}, {5, 5}, {6, 6}]))

      steps = Enum.zip([{5, 4} | path], path)

      assert Enum.all?(steps, fn {from, to} ->
               Cell.step_traversable?("test_map", from, to)
             end)
    end

    test "returns no_path when completely blocked", %{map_data: map_data} do
      map_data =
        map_data
        |> MapData.set_cell(4, 4, GatType.wall())
        |> MapData.set_cell(4, 5, GatType.wall())
        |> MapData.set_cell(4, 6, GatType.wall())
        |> MapData.set_cell(5, 4, GatType.wall())
        |> MapData.set_cell(5, 6, GatType.wall())
        |> MapData.set_cell(6, 4, GatType.wall())
        |> MapData.set_cell(6, 5, GatType.wall())
        |> MapData.set_cell(6, 6, GatType.wall())

      cache(map_data)

      assert {:error, :no_path} = Pathfinding.find_path(map_data, {0, 0}, {5, 5})
    end

    test "returns error when goal is not walkable", %{map_data: map_data} do
      map_data = MapData.set_cell(map_data, 5, 5, GatType.wall())
      cache(map_data)
      assert {:error, :goal_not_walkable} = Pathfinding.find_path(map_data, {0, 0}, {5, 5})
    end

    test "handles water cells as walkable", %{map_data: map_data} do
      map_data =
        map_data
        |> MapData.set_cell(3, 5, GatType.water())
        |> MapData.set_cell(4, 5, GatType.water())

      cache(map_data)

      assert {:ok, path} = Pathfinding.find_path(map_data, {0, 5}, {5, 5})
      assert {3, 5} in path
      assert {4, 5} in path
    end

    test "prefers straight paths over diagonal when equal distance" do
      map_data = MapData.new("test_map", 20, 20)
      cache(map_data)

      assert {:ok, path} = Pathfinding.find_path(map_data, {0, 0}, {10, 0})
      assert Enum.all?(path, fn {_x, y} -> y == 0 end)
    end

    test "avoids an active dynamic blocker and uses the base cell after removal", %{
      map_data: map_data
    } do
      :ok = Cell.put("test_map", 1, 0, :barrier, 1, blocks_movement: true)

      assert {:ok, blocked_path} = Pathfinding.find_path(map_data, {0, 0}, {2, 0})
      refute {1, 0} in blocked_path

      :ok = Cell.delete("test_map", 1, 0, :barrier, 1)

      assert {:ok, [{1, 0}, {2, 0}]} = Pathfinding.find_path(map_data, {0, 0}, {2, 0})
      assert {:ok, ^map_data} = MapCache.get("test_map")
    end
  end

  describe "simplify_path/1" do
    setup :setup_ets_tables

    setup do
      :ets.insert(EtsTable.table_for(:map_cache), {"test_map", MapData.new("test_map", 10, 10)})
      :ok
    end

    test "returns path as-is when 2 or fewer points" do
      assert [] = Pathfinding.simplify_path([])
      assert [{1, 1}] = Pathfinding.simplify_path([{1, 1}])
      assert [{1, 1}, {2, 2}] = Pathfinding.simplify_path([{1, 1}, {2, 2}])
    end

    test "removes intermediate points in straight horizontal line" do
      path = [{0, 5}, {1, 5}, {2, 5}, {3, 5}, {4, 5}, {5, 5}]
      simplified = Pathfinding.simplify_path(path)

      assert [{0, 5}, {5, 5}] = simplified
    end

    test "removes intermediate points in straight vertical line" do
      path = [{5, 0}, {5, 1}, {5, 2}, {5, 3}, {5, 4}, {5, 5}]
      simplified = Pathfinding.simplify_path(path)

      assert [{5, 0}, {5, 5}] = simplified
    end

    test "removes intermediate points in diagonal line" do
      path = [{0, 0}, {1, 1}, {2, 2}, {3, 3}, {4, 4}, {5, 5}]
      simplified = Pathfinding.simplify_path(path)

      assert [{0, 0}, {5, 5}] = simplified
    end

    test "keeps turning points" do
      # L-shaped path
      path = [{0, 0}, {1, 0}, {2, 0}, {3, 0}, {3, 1}, {3, 2}, {3, 3}]
      simplified = Pathfinding.simplify_path(path)

      assert [{0, 0}, {3, 0}, {3, 3}] = simplified
    end

    test "keeps a path unsimplified while it contains a dynamic blocker" do
      path = [{0, 0}, {1, 0}, {2, 0}]
      :ok = Cell.put("test_map", 1, 0, :barrier, 2, blocks_movement: true)

      assert Pathfinding.simplify_path(path, "test_map") == path

      :ok = Cell.delete("test_map", 1, 0, :barrier, 2)
      assert Pathfinding.simplify_path(path, "test_map") == [{0, 0}, {2, 0}]
    end

    test "handles complex path with multiple turns" do
      # Zigzag path
      path = [
        # Horizontal
        {0, 0},
        {1, 0},
        {2, 0},
        # Vertical
        {2, 1},
        {2, 2},
        # Horizontal
        {3, 2},
        {4, 2},
        # Vertical
        {4, 3},
        {4, 4},
        {4, 5}
      ]

      simplified = Pathfinding.simplify_path(path)

      assert [{0, 0}, {2, 0}, {2, 2}, {4, 2}, {4, 5}] = simplified
    end
  end

  defp cache(map_data) do
    :ets.insert(EtsTable.table_for(:map_cache), {map_data.name, map_data})
  end
end
