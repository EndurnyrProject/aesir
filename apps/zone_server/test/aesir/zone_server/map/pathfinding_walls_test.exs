defmodule Aesir.ZoneServer.Map.PathfindingWallsTest do
  @moduledoc """
  Verifies the walls-only path search (`cells: :walls`): a reach check that
  crosses cliffs but not walls, with diagonal steps needing both cut cells
  free of walls.
  """

  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Pathfinding

  setup :setup_ets_tables

  setup do
    map =
      MapData.new("walls_test", 4, 4)
      |> MapData.set_cell(1, 1, GatType.cliff())
      |> MapData.set_cell(2, 0, GatType.wall())
      |> MapData.set_cell(0, 2, GatType.wall())

    :ets.insert(EtsTable.table_for(:map_cache), {"walls_test", map})
    {:ok, map: map}
  end

  test "crosses a cliff that the walkable search refuses", %{map: map} do
    assert {:error, :no_path} = Pathfinding.find_path(map, {0, 0}, {2, 2})
    assert {:ok, [{1, 1}, {2, 2}]} = Pathfinding.find_path(map, {0, 0}, {2, 2}, cells: :walls)
  end

  test "a wall goal is unreachable and a diagonal cut by walls is blocked", %{map: map} do
    assert {:error, :goal_not_walkable} =
             Pathfinding.find_path(map, {0, 0}, {2, 0}, cells: :walls)

    cornered =
      map
      |> MapData.set_cell(1, 0, GatType.wall())
      |> MapData.set_cell(0, 1, GatType.wall())

    :ets.insert(EtsTable.table_for(:map_cache), {"walls_test", cornered})

    assert {:error, :no_path} = Pathfinding.find_path(cornered, {0, 0}, {2, 2}, cells: :walls)
  end
end
