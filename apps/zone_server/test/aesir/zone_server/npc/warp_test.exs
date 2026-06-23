defmodule Aesir.ZoneServer.Npc.WarpTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warp.Registry

  defp warp(overrides) do
    struct!(
      Warp,
      Keyword.merge([id: "w", map: "prontera", to_map: "izlude", to_x: 0, to_y: 0], overrides)
    )
  end

  describe "cell_in_area?/3" do
    test "centre cell is inside the area" do
      warp = warp(x: 150, y: 20, xs: 1, ys: 1)

      assert Registry.cell_in_area?(warp, 150, 20)
    end

    test "the four edge cells of an xs:1,ys:1 warp are inside" do
      warp = warp(x: 150, y: 20, xs: 1, ys: 1)

      assert Registry.cell_in_area?(warp, 151, 20)
      assert Registry.cell_in_area?(warp, 149, 20)
      assert Registry.cell_in_area?(warp, 150, 21)
      assert Registry.cell_in_area?(warp, 150, 19)
    end

    test "one step outside each edge is outside" do
      warp = warp(x: 150, y: 20, xs: 1, ys: 1)

      refute Registry.cell_in_area?(warp, 152, 20)
      refute Registry.cell_in_area?(warp, 148, 20)
      refute Registry.cell_in_area?(warp, 150, 22)
      refute Registry.cell_in_area?(warp, 150, 18)
    end

    test "a xs:0, ys:0 warp reduces to its single centre cell" do
      warp = warp(x: 150, y: 20, xs: 0, ys: 0)

      assert Registry.cell_in_area?(warp, 150, 20)
      refute Registry.cell_in_area?(warp, 151, 20)
      refute Registry.cell_in_area?(warp, 149, 20)
      refute Registry.cell_in_area?(warp, 150, 21)
      refute Registry.cell_in_area?(warp, 150, 19)
    end
  end

  describe "hit?/3" do
    test "returns the matching warp when one warp in the list contains the cell" do
      warp_a = warp(id: "a", x: 150, y: 20, xs: 1, ys: 1)
      warp_b = warp(id: "b", x: 300, y: 40, xs: 1, ys: 1)

      assert Registry.hit?([warp_a, warp_b], 150, 20) == warp_a
      assert Registry.hit?([warp_a, warp_b], 300, 40) == warp_b
    end

    test "returns nil when no warp contains the cell" do
      warp_a = warp(id: "a", x: 150, y: 20, xs: 1, ys: 1)
      warp_b = warp(id: "b", x: 300, y: 40, xs: 1, ys: 1)

      assert Registry.hit?([warp_a, warp_b], 999, 999) == nil
      assert Registry.hit?([], 150, 20) == nil
    end

    test "returns the first match when two warps overlap on the cell" do
      first = warp(id: "first", x: 150, y: 20, xs: 2, ys: 2)
      second = warp(id: "second", x: 150, y: 20, xs: 2, ys: 2)

      assert Registry.hit?([first, second], 150, 20) == first
      assert Registry.hit?([second, first], 150, 20) == second
    end
  end
end
