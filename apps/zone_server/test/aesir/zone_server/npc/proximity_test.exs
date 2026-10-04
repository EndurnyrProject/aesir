defmodule Aesir.ZoneServer.Npc.ProximityTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Npc.Registry
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
end
