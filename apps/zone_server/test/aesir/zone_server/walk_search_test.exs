defmodule Aesir.ZoneServer.WalkSearchTest do
  @moduledoc """
  The client's walk search: its heuristic and tie order, the 32x32 node
  window, the easy branch, the unit walk-length refusals, and the map edge.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Pathfinding

  @map "walk_search_map"

  setup :setup_ets_tables

  setup do
    {:ok, map: cache(MapData.new(@map, 64, 64))}
  end

  describe "the client's search" do
    test "takes the diagonal first on an open map", %{map: map} do
      assert {:ok, [{6, 6}, {7, 6}, {8, 6}, {9, 6}]} = Pathfinding.find_path(map, {5, 5}, {9, 6})
    end

    test "walks around a wall without cutting its corner", %{map: map} do
      map = cache(MapData.set_cell(map, 6, 5, GatType.wall()))

      assert {:ok, path} = Pathfinding.find_path(map, {5, 5}, {7, 5})
      assert length(path) == 4
      refute {6, 5} in path
    end

    test "holds thirty straight steps in the node window but not thirty-one", %{map: map} do
      assert {:ok, path} = Pathfinding.find_path(map, {5, 5}, {5, 35})
      assert length(path) == 30
      assert {:error, :no_path} = Pathfinding.find_path(map, {5, 5}, {5, 36})
    end

    test "the easy branch stops at the first blocked cell and never checks corners", %{map: map} do
      map = cache(MapData.set_cell(map, 7, 7, GatType.wall()))

      assert {:ok, [{6, 6}]} = Pathfinding.find_path(map, {5, 5}, {6, 6}, easy: true)
      assert {:error, :no_path} = Pathfinding.find_path(map, {5, 5}, {8, 8}, easy: true)

      map =
        map
        |> MapData.set_cell(6, 5, GatType.wall())
        |> MapData.set_cell(5, 6, GatType.wall())
        |> cache()

      assert {:ok, [{6, 6}]} = Pathfinding.find_path(map, {5, 5}, {6, 6}, easy: true)
      assert {:ok, [_, _ | _]} = Pathfinding.find_path(map, {5, 5}, {6, 6})
    end

    test "a goal on the map's last row or column is not walkable", %{map: map} do
      assert {:error, :goal_not_walkable} = Pathfinding.find_path(map, {5, 5}, {63, 5})
      assert {:error, :goal_not_walkable} = Pathfinding.find_path(map, {5, 5}, {5, 63})
      assert {:ok, _path} = Pathfinding.find_path(map, {5, 5}, {20, 5})
    end

    test "a reach check (cells: :noreach) walks the last row and column", %{map: map} do
      assert {:ok, path} = Pathfinding.find_path(map, {60, 5}, {63, 5}, cells: :noreach)
      assert length(path) == 3
      assert {:ok, [_ | _]} = Pathfinding.find_path(map, {5, 60}, {5, 63}, cells: :noreach)

      assert {:ok, [{61, 6}]} =
               Pathfinding.find_path(map, {60, 5}, {61, 6}, easy: true, cells: :noreach)

      map = cache(MapData.set_cell(map, 61, 5, GatType.wall()))

      assert {:error, :goal_not_walkable} =
               Pathfinding.find_path(map, {60, 5}, {61, 5}, cells: :noreach)
    end
  end

  describe "walk_path/4 and rewalk_path/4" do
    test "a new walk refuses more than seventeen steps", %{map: map} do
      assert {:ok, path} = Pathfinding.walk_path(map, {5, 5}, {5, 22})
      assert length(path) == 17
      assert {:error, :too_far} = Pathfinding.walk_path(map, {5, 5}, {5, 23})
      assert {:ok, path} = Pathfinding.rewalk_path(map, {5, 5}, {5, 23})
      assert length(path) == 18
    end

    test "more than fourteen steps need a clear straight line to the goal", %{map: map} do
      map = cache(MapData.set_cell(map, 5, 13, GatType.wall()))

      assert {:ok, path} = Pathfinding.find_path(map, {5, 5}, {5, 20})
      assert length(path) > 14
      assert {:error, :too_far} = Pathfinding.walk_path(map, {5, 5}, {5, 20})
      assert {:error, :too_far} = Pathfinding.rewalk_path(map, {5, 5}, {5, 20})

      map = cache(MapData.set_cell(map, 5, 8, GatType.wall()))
      assert {:ok, path} = Pathfinding.walk_path(map, {5, 5}, {5, 12})
      assert length(path) <= 14
      assert {:ok, path} = Pathfinding.walk_path(map, {5, 14}, {5, 29})
      assert length(path) == 15
    end

    test "an easy walk is refused past seventeen steps too", %{map: map} do
      assert {:ok, path} = Pathfinding.walk_path(map, {5, 5}, {22, 22}, easy: true)
      assert length(path) == 17
      assert {:error, :too_far} = Pathfinding.walk_path(map, {5, 5}, {23, 23}, easy: true)
    end
  end

  describe "the map edge" do
    test "the last row and column are impassable but not walls", %{map: map} do
      refute MapData.walkable?(map, 63, 5)
      refute MapData.walkable?(map, 5, 63)
      assert MapData.walkable?(map, 62, 62)
      assert MapData.check_cell(map, 63, 5, :chk_nopass)
      refute MapData.check_cell(map, 63, 5, :chk_pass)
      refute MapData.check_cell(map, 63, 5, :chk_wall)
    end
  end

  defp cache(map) do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, map})
    map
  end
end
