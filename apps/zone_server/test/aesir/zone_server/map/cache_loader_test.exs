defmodule Aesir.ZoneServer.Map.CacheLoaderTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Map.CacheLoader
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData

  @cache_path Path.join(:code.priv_dir(:zone_server), "maps.mcache")

  setup_all do
    {:ok, cache_maps} = CacheLoader.load_cache(@cache_path)
    {:ok, cache_maps: cache_maps}
  end

  describe "load_cache/1" do
    test "successfully loads the rAthena map cache file", %{cache_maps: cache_maps} do
      assert is_map(cache_maps)
      assert map_size(cache_maps) > 0
    end

    test "returns error for non-existent cache file" do
      assert {:error, _reason} = CacheLoader.load_cache("non_existent.mcache")
    end
  end

  describe "load_map_from_cache/2" do
    test "loads pprontera from cache", %{cache_maps: cache_maps} do
      pprontera = Map.get(cache_maps, "pprontera")
      assert %MapData{} = pprontera

      assert pprontera.name == "pprontera"
      assert pprontera.xs > 0
      assert pprontera.ys > 0
      assert pprontera.cells != nil
    end

    test "loads multiple common maps from cache", %{cache_maps: cache_maps} do
      common_maps = ["pprontera", "1@gl_k", "bat_c03", "izlude_d", "gef_fild08"]

      for map_name <- common_maps do
        map_data = Map.get(cache_maps, map_name)
        assert %MapData{} = map_data, "Failed to load #{map_name}"
        assert map_data.name == map_name
      end
    end

    test "returns error for non-existent map", %{cache_maps: cache_maps} do
      assert Map.get(cache_maps, "non_existent_map") == nil
    end
  end

  describe "map data integrity" do
    test "pprontera has expected dimensions", %{cache_maps: cache_maps} do
      pprontera = Map.get(cache_maps, "pprontera")

      assert pprontera.xs > 0
      assert pprontera.ys > 0
    end

    test "cells are properly loaded", %{cache_maps: cache_maps} do
      pprontera = Map.get(cache_maps, "pprontera")

      total_cells = pprontera.xs * pprontera.ys

      assert byte_size(pprontera.cells) == total_cells

      for i <- 0..min(100, total_cells - 1) do
        <<_::binary-size(i), gat_type::8, _::binary>> = pprontera.cells
        assert gat_type in 0..6
      end
    end

    test "map has both walkable and non-walkable cells", %{cache_maps: cache_maps} do
      pprontera = Map.get(cache_maps, "pprontera")

      sample_size = min(1000, pprontera.xs * pprontera.ys)

      cells_sample =
        for i <- 0..(sample_size - 1) do
          <<_::binary-size(i), gat_type::8, _::binary>> = pprontera.cells
          gat_type
        end

      walkable_count = Enum.count(cells_sample, &GatType.is_walkable?/1)

      non_walkable_count =
        Enum.count(cells_sample, &(not GatType.is_walkable?(&1)))

      assert walkable_count > 0, "No walkable cells found"
      assert non_walkable_count > 0, "No non-walkable cells found"
    end
  end
end
