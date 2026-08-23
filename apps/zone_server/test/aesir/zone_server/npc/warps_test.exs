defmodule Aesir.ZoneServer.Npc.WarpsTest do
  use ExUnit.Case, async: false
  import Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  setup do
    :persistent_term.erase(Warps)
    stub(MapCache, :get, fn _ -> {:ok, %MapData{}} end)
    stub(MapData, :walkable?, fn _, _, _ -> true end)
    on_exit(fn -> :persistent_term.erase(Warps) end)
    :ok
  end

  describe "for_map/1" do
    test "loads a map's warps as %Warp{} structs without an explicit reload" do
      assert {:ok, [%Warp{map: "prontera", sprite: 45} | _]} = Warps.for_map("prontera")
    end

    test "loads warps for another populated map" do
      assert {:ok, [%Warp{map: "geffen", sprite: 45} | _]} = Warps.for_map("geffen")
    end

    test "returns :error for a map with no warps" do
      assert :error = Warps.for_map("nonexistent")
    end
  end

  describe "all/0" do
    test "returns warps keyed by source map name" do
      assert %{"prontera" => [%Warp{} | _], "geffen" => [%Warp{} | _]} = Warps.all()
    end
  end

  describe "reload/0" do
    test "rebuilds the cached index" do
      assert :ok = Warps.reload()
      assert {:ok, _} = Warps.for_map("prontera")
    end
  end

  describe "persistent_term warming" do
    test "for_map/1 populates :persistent_term without an explicit reload" do
      refute :persistent_term.get(Warps, nil) != nil

      Warps.for_map("prontera")

      assert %{} = :persistent_term.get(Warps, nil)
    end
  end
end
