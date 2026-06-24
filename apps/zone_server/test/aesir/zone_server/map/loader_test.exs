defmodule Aesir.ZoneServer.Map.LoaderTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Map.Loader
  alias Aesir.ZoneServer.Map.MapData

  setup_all do
    {:ok, cache_maps} = Loader.load_all_from_cache()
    {:ok, cache_maps: cache_maps}
  end

  describe "load_map/2" do
    test "loads map with custom cache path" do
      cache_path = Path.join(:code.priv_dir(:zone_server), "maps.mcache")
      assert {:ok, %MapData{} = map} = Loader.load_map("prontera", cache_path: cache_path)
      assert map.name == "prontera"
    end

    test "returns error for non-existent map" do
      assert {:error, _reason} = Loader.load_map("totally_fake_map")
    end
  end

  describe "load_all_from_cache/1" do
    test "loads all maps from default cache", %{cache_maps: cache_maps} do
      assert is_map(cache_maps)
      assert map_size(cache_maps) > 0

      assert Map.has_key?(cache_maps, "prontera")
    end
  end
end
