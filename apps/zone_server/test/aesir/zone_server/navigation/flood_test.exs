defmodule Aesir.ZoneServer.Navigation.FloodTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Navigation.Flood
  alias Aesir.ZoneServer.Pathfinding

  setup :setup_ets_tables

  test "flood cost agrees with a mixed-step pathfinder path" do
    map_data = cache(MapData.new("navigation_flood_mixed", 6, 6))
    start = {0, 0}
    target = {4, 2}

    assert {:ok, path} = Pathfinding.find_path(map_data, start, target)
    steps = Enum.zip([start | path], path)

    assert Enum.any?(steps, &diagonal?/1)
    assert Enum.any?(steps, &(not diagonal?(&1)))

    costs = Flood.costs(map_data, start, MapSet.new([target]))

    assert_in_delta costs[target], Flood.path_cost(start, path), 1.0e-12
  end

  test "omits an unreachable target" do
    enclosed = {3, 3}
    reachable = {6, 6}

    map_data =
      for x <- 2..4,
          y <- 2..4,
          {x, y} != enclosed,
          reduce: MapData.new("navigation_flood_enclosed", 7, 7) do
        map_data -> MapData.set_cell(map_data, x, y, GatType.wall())
      end
      |> cache()

    costs = Flood.costs(map_data, {0, 0}, MapSet.new([enclosed, reachable]))

    assert Map.has_key?(costs, reachable)
    refute Map.has_key?(costs, enclosed)
  end

  test "flood and pathfinder agree when a blocked direct route forces a detour" do
    start = {0, 3}
    target = {6, 3}

    map_data =
      Enum.reduce(1..5, MapData.new("navigation_flood_detour", 7, 7), fn y, map_data ->
        MapData.set_cell(map_data, 3, y, GatType.wall())
      end)
      |> cache()

    assert {:ok, path} = Pathfinding.find_path(map_data, start, target)
    assert Enum.any?(path, fn {_x, y} -> y in [0, 6] end)

    costs = Flood.costs(map_data, start, MapSet.new([target]))

    assert_in_delta costs[target], Flood.path_cost(start, path), 1.0e-12
  end

  test "a cyclic map is exhausted without repeated expansion" do
    map_data = cache(MapData.new("navigation_flood_cycle", 40, 40))

    task = Task.async(fn -> Flood.costs(map_data, {0, 0}, MapSet.new([{-1, -1}])) end)

    assert Task.await(task, 1_000) == %{}
  end

  defp cache(map_data) do
    :ets.insert(EtsTable.table_for(:map_cache), {map_data.name, map_data})
    map_data
  end

  defp diagonal?({{x1, y1}, {x2, y2}}), do: x1 != x2 and y1 != y2
end
