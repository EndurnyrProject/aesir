defmodule Aesir.ZoneServer.Map.MapCacheTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData

  setup :setup_ets_tables

  test "detects cardinal impassable neighbors" do
    for {x, y} <- [{1, 0}, {0, 1}, {2, 1}, {1, 2}] do
      map = MapData.new("adjacency", 3, 3) |> MapData.set_cell(x, y, GatType.wall())
      cache(map)

      assert MapCache.adjacent_impassable?("adjacency", 1, 1)
    end
  end

  test "detects diagonal impassable neighbors" do
    for {x, y} <- [{0, 0}, {2, 0}, {0, 2}, {2, 2}] do
      map = MapData.new("adjacency", 3, 3) |> MapData.set_cell(x, y, GatType.wall())
      cache(map)

      assert MapCache.adjacent_impassable?("adjacency", 1, 1)
    end
  end

  test "returns false for an open neighbor ring" do
    cache(MapData.new("adjacency", 3, 3))

    refute MapCache.adjacent_impassable?("adjacency", 1, 1)
  end

  test "does not count out-of-bounds neighbors" do
    cache(MapData.new("adjacency", 1, 1))

    refute MapCache.adjacent_impassable?("adjacency", 0, 0)
  end

  test "ignores NPC occupancy and dynamic blockers" do
    map = MapData.new("adjacency", 3, 3) |> MapData.set_cell_flag(1, 0, :npc, true)
    cache(map)
    :ok = Cell.put("adjacency", 0, 1, :wall, 1, blocks_movement: true)

    refute MapCache.adjacent_impassable?("adjacency", 1, 1)
  end

  defp cache(map), do: :ets.insert(EtsTable.table_for(:map_cache), {map.name, map})
end
