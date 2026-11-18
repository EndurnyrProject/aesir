defmodule Aesir.ZoneServer.Map.CacheLoaderTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Map.CacheLoader
  alias Aesir.ZoneServer.Map.MapData

  @cache_path Path.join(:code.priv_dir(:zone_server), "maps.mcache")

  describe "load_cache/1" do
    test "keys every map in the shipped cache by its name, with one cell per tile" do
      {:ok, cache_maps} = CacheLoader.load_cache(@cache_path)

      assert map_size(cache_maps) > 0

      for {map_name, map_data} <- cache_maps do
        assert %MapData{name: ^map_name, xs: xs, ys: ys, cells: cells} = map_data
        assert byte_size(cells) == xs * ys, "#{map_name} has a truncated cell grid"
      end
    end

    test "returns error for non-existent cache file" do
      assert {:error, _reason} = CacheLoader.load_cache("non_existent.mcache")
    end
  end
end
