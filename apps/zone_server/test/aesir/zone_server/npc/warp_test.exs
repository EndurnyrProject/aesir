defmodule Aesir.ZoneServer.Npc.WarpTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Npc.Warp.Registry

  describe "cell_in_area?/3" do
    test "centre cell is inside the area" do
      warp = build(:warp, map: "prontera", x: 150, y: 20, xs: 1, ys: 1)

      assert Registry.cell_in_area?(warp, 150, 20)
    end

    test "the four edge cells of an xs:1,ys:1 warp are inside" do
      warp = build(:warp, map: "prontera", x: 150, y: 20, xs: 1, ys: 1)

      assert Registry.cell_in_area?(warp, 151, 20)
      assert Registry.cell_in_area?(warp, 149, 20)
      assert Registry.cell_in_area?(warp, 150, 21)
      assert Registry.cell_in_area?(warp, 150, 19)
    end

    test "one step outside each edge is outside" do
      warp = build(:warp, map: "prontera", x: 150, y: 20, xs: 1, ys: 1)

      refute Registry.cell_in_area?(warp, 152, 20)
      refute Registry.cell_in_area?(warp, 148, 20)
      refute Registry.cell_in_area?(warp, 150, 22)
      refute Registry.cell_in_area?(warp, 150, 18)
    end

    test "a xs:0, ys:0 warp reduces to its single centre cell" do
      warp = build(:warp, map: "prontera", x: 150, y: 20, xs: 0, ys: 0)

      assert Registry.cell_in_area?(warp, 150, 20)
      refute Registry.cell_in_area?(warp, 151, 20)
      refute Registry.cell_in_area?(warp, 149, 20)
      refute Registry.cell_in_area?(warp, 150, 21)
      refute Registry.cell_in_area?(warp, 150, 19)
    end
  end

  describe "hit?/3" do
    test "returns the matching warp when one warp in the list contains the cell" do
      warp_a = build(:warp, map: "prontera", id: "a", x: 150, y: 20, xs: 1, ys: 1)
      warp_b = build(:warp, map: "prontera", id: "b", x: 300, y: 40, xs: 1, ys: 1)

      assert Registry.hit?([warp_a, warp_b], 150, 20) == warp_a
      assert Registry.hit?([warp_a, warp_b], 300, 40) == warp_b
    end

    test "returns nil when no warp contains the cell" do
      warp_a = build(:warp, map: "prontera", id: "a", x: 150, y: 20, xs: 1, ys: 1)
      warp_b = build(:warp, map: "prontera", id: "b", x: 300, y: 40, xs: 1, ys: 1)

      assert Registry.hit?([warp_a, warp_b], 999, 999) == nil
      assert Registry.hit?([], 150, 20) == nil
    end

    test "returns the first match when two warps overlap on the cell" do
      first = build(:warp, map: "prontera", id: "first", x: 150, y: 20, xs: 2, ys: 2)
      second = build(:warp, map: "prontera", id: "second", x: 150, y: 20, xs: 2, ys: 2)

      assert Registry.hit?([first, second], 150, 20) == first
      assert Registry.hit?([second, first], 150, 20) == second
    end
  end

  describe "entity_id/1" do
    @warp_id_base 0x4000_0000

    test "is distinct for two warps on the same map with different cells" do
      a = build(:warp, map: "prontera", id: "a", x: 150, y: 20)
      b = build(:warp, map: "prontera", id: "b", x: 200, y: 40)

      assert Registry.entity_id(a) != Registry.entity_id(b)
    end

    test "lives in the reserved high gid range, never colliding with mob or player ids" do
      warp = build(:warp, map: "prontera", x: 150, y: 20)

      gid = Registry.entity_id(warp)

      assert gid >= @warp_id_base
      # Mob instance_ids are allocated in 2..1_999_999; player character_ids are
      # DB auto-increment PKs starting at 1. The reserved base sits well above both.
      refute gid in 1..1_999_999
    end
  end
end
