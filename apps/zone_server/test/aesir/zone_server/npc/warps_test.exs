defmodule Aesir.ZoneServer.Npc.WarpsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  setup do
    :persistent_term.erase(Warps)
    on_exit(fn -> :persistent_term.erase(Warps) end)
    :ok
  end

  describe "for_map/1" do
    test "returns the seed warps for prontera without an explicit reload" do
      assert {:ok, warps} = Warps.for_map("prontera")

      assert [%Warp{} = warp | _] = warps
      assert warp.map == "prontera"
      assert warp.to_map == "izlude"
      assert warp.to_x == 150
      assert warp.to_y == 190
      assert warp.sprite == 45
    end

    test "returns the return warp for izlude" do
      assert {:ok, warps} = Warps.for_map("izlude")

      assert [%Warp{} = warp | _] = warps
      assert warp.map == "izlude"
      assert warp.to_map == "prontera"
    end

    test "returns :error for a map with no warps" do
      assert :error = Warps.for_map("nonexistent")
    end
  end

  describe "all/0" do
    test "returns a map keyed by map name" do
      all = Warps.all()

      assert is_map(all)
      assert Map.has_key?(all, "prontera")
      assert Map.has_key?(all, "izlude")
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
