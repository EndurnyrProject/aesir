defmodule Aesir.ZoneServer.Npc.ProximityTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  setup :set_mimic_private

  test "touch rectangles are found at their edge, but not one cell beyond range" do
    stub(Registry, :touch_rects, fn "test" -> [{1, 12..16, 8..12}] end)
    stub(Warps, :for_map, fn "test" -> :error end)
    assert Proximity.touch_area_within?("test", 10, 10, 2)
    refute Proximity.touch_area_within?("test", 9, 10, 2)
    refute Proximity.touch_area_within?("test", 10, 5, 2)
  end

  test "a single-cell warp on the box edge is found" do
    stub(Registry, :touch_rects, fn "test" -> [] end)

    warp = %Warp{
      id: "edge",
      map: "test",
      x: 11,
      y: 11,
      to_map: "test",
      to_x: 20,
      to_y: 20,
      xs: 0,
      ys: 0
    }

    stub(Warps, :for_map, fn "test" -> {:ok, [warp]} end)
    assert Proximity.touch_area_within?("test", 10, 10, 1)
    refute Proximity.touch_area_within?("test", 9, 10, 1)
  end

  test "warp trigger edges, rather than just centers, are checked" do
    stub(Registry, :touch_rects, fn "test" -> [] end)

    warp = %Warp{
      id: "wide",
      map: "test",
      x: 15,
      y: 15,
      to_map: "test",
      to_x: 20,
      to_y: 20,
      xs: 3,
      ys: 3
    }

    stub(Warps, :for_map, fn "test" -> {:ok, [warp]} end)
    assert Proximity.touch_area_within?("test", 10, 10, 2)
    refute Proximity.touch_area_within?("test", 9, 10, 2)
  end

  test "an unknown map has no touch areas" do
    stub(Registry, :touch_rects, fn "unknown" -> [] end)
    stub(Warps, :for_map, fn "unknown" -> :error end)
    refute Proximity.touch_area_within?("unknown", 10, 10, 0)
  end

  describe "npc_near?/3" do
    setup do
      stub(Warps, :for_map, fn _map -> :error end)
      stub(Shops, :for_map, fn _map -> :error end)
      :ok
    end

    test "an NPC three cells away on both axes is near, four cells away is not" do
      stub_placements([placement(13, 13, "corner")])

      assert Proximity.npc_near?("prox_map", 10, 10)
      refute Proximity.npc_near?("prox_map", 9, 10)
      refute Proximity.npc_near?("other_map", 10, 10)
    end

    test "a hidden or disabled NPC is not near" do
      hidden = placement(11, 10, "hidden")
      disabled = placement(10, 11, "disabled")
      stub_placements([hidden, disabled])
      put_flags(hidden, true, true)
      put_flags(disabled, false, false)

      refute Proximity.npc_near?("prox_map", 10, 10)
    end

    test "a warp portal or a shop counts as an NPC" do
      stub_placements([])
      warp = %Warp{id: "w", map: "prox_map", x: 7, y: 10, to_map: "x", to_x: 1, to_y: 1}
      shop = %Shop{id: "s", map: "prox_map", x: 20, y: 20, dir: 0, sprite: 1}
      stub(Warps, :for_map, fn "prox_map" -> {:ok, [warp]} end)
      stub(Shops, :for_map, fn "prox_map" -> {:ok, [shop]} end)

      assert Proximity.npc_near?("prox_map", 10, 10)
      assert Proximity.npc_near?("prox_map", 17, 23)
      refute Proximity.npc_near?("prox_map", 14, 14)
    end
  end

  defp placement(x, y, name),
    do: %Placement{map: "prox_map", x: x, y: y, sprite: 1, name: name, unique_name: name}

  defp stub_placements(placements),
    do: stub(Registry, :entries, fn -> Enum.map(placements, &{__MODULE__, &1}) end)

  defp put_flags(placement, enabled?, hidden?) do
    gid = Registry.entity_id(placement)
    :ets.insert(:npc_session_flags, {gid, enabled?, hidden?})
    on_exit(fn -> :ets.delete(:npc_session_flags, gid) end)
  end
end
