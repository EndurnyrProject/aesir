defmodule Aesir.ZoneServer.Map.LoaderTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Map.{Loader, MapData}

  setup_all do
    {:ok, cache_maps} = Loader.load_all_from_cache()
    {:ok, cache_maps: cache_maps}
  end

  describe "load_map/2" do
    test "loads pprontera using default cache" do
      assert {:ok, %MapData{} = map} = Loader.load_map("pprontera")
      assert map.name == "pprontera"
      assert map.xs > 0
      assert map.ys > 0
    end

    test "loads map with custom cache path" do
      cache_path = Path.join(:code.priv_dir(:zone_server), "maps.mcache")
      assert {:ok, %MapData{} = map} = Loader.load_map("pprontera", cache_path: cache_path)
      assert map.name == "pprontera"
    end

    test "returns error for non-existent map" do
      assert {:error, _reason} = Loader.load_map("totally_fake_map")
    end
  end

  describe "load_all_from_cache/1" do
    test "loads all maps from default cache", %{cache_maps: cache_maps} do
      assert is_map(cache_maps)
      assert map_size(cache_maps) > 0

      assert Map.has_key?(cache_maps, "pprontera")
    end
  end
end

