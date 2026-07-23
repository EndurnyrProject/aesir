defmodule Aesir.ZoneServer.Map.LineOfSightTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapData

  setup :setup_ets_tables

  defp cache_map(map_name, map), do: :ets.insert(EtsTable.table_for(:map_cache), {map_name, map})

  test "rAthena integer traversal catches the diagonal cell symmetric Bresenham skips" do
    map =
      "line_of_sight"
      |> MapData.new(100, 100)
      |> MapData.set_cell(51, 60, GatType.wall())

    true = cache_map("line_of_sight", map)

    refute LineOfSight.clear?("line_of_sight", {50, 60}, {54, 62})
  end

  test "a dynamic projectile blocker stops a traversed diagonal cell" do
    map = MapData.new("line_of_sight", 100, 100)
    :ets.insert(EtsTable.table_for(:map_cache), {"line_of_sight", map})
    :ok = Cell.put("line_of_sight", 51, 60, :barrier, 1, blocks_projectiles: true)

    refute LineOfSight.clear?("line_of_sight", {50, 60}, {54, 62})
  end

  test "a blocked destination cell is not counted as an intervening obstruction" do
    map = MapData.new("line_of_sight", 100, 100)
    true = cache_map("line_of_sight", map)
    :ok = Cell.put("line_of_sight", 54, 62, :barrier, 1, blocks_projectiles: true)

    assert LineOfSight.clear?("line_of_sight", {50, 60}, {54, 62})
  end

  test "walkable? clears an open diagonal line" do
    map = MapData.new("line_of_sight", 100, 100)
    true = cache_map("line_of_sight", map)

    assert LineOfSight.walkable?("line_of_sight", {50, 50}, {53, 53})
  end

  test "walkable? rejects a diagonal step that cuts the corner between blocked cells" do
    map =
      "line_of_sight"
      |> MapData.new(100, 100)
      |> MapData.set_cell(51, 50, GatType.wall())
      |> MapData.set_cell(50, 51, GatType.wall())

    true = cache_map("line_of_sight", map)

    assert Cell.traversable?("line_of_sight", 51, 51)
    refute LineOfSight.walkable?("line_of_sight", {50, 50}, {53, 53})
  end
end
