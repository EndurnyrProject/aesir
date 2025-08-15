defmodule Aesir.ZoneServer.Map.MapDataTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData

  describe "new/3" do
    test "creates a new map with given dimensions" do
      map = MapData.new("test_map", 10, 20)

      assert map.name == "test_map"
      assert map.xs == 10
      assert map.ys == 20
      assert byte_size(map.cells) == 200
      assert map.dynamic_cells == %{}
      assert map.npcs == []
      assert map.users == 0
      assert map.zone == 0
    end

    test "initializes all cells as walkable ground" do
      map = MapData.new("test_map", 5, 5)

      # All cells should be walkable
      for i <- 0..24 do
        <<_::binary-size(i), gat_type::8, _::binary>> = map.cells
        assert gat_type == GatType.walkable()
      end
    end
  end

  describe "get_cell/3" do
    setup do
      map = MapData.new("test_map", 10, 10)
      {:ok, map: map}
    end

    test "returns GAT type for valid coordinates", %{map: map} do
      assert MapData.get_cell(map, 0, 0) == GatType.walkable()
      assert MapData.get_cell(map, 5, 5) == GatType.walkable()
      assert MapData.get_cell(map, 9, 9) == GatType.walkable()
    end

    test "returns nil for out of bounds coordinates", %{map: map} do
      assert MapData.get_cell(map, -1, 0) == nil
      assert MapData.get_cell(map, 0, -1) == nil
      assert MapData.get_cell(map, 10, 0) == nil
      assert MapData.get_cell(map, 0, 10) == nil
    end
  end

  describe "set_cell/4" do
    setup do
      map = MapData.new("test_map", 10, 10)
      {:ok, map: map}
    end

    test "sets GAT type at valid coordinates", %{map: map} do
      updated_map = MapData.set_cell(map, 5, 5, GatType.wall())
      assert MapData.get_cell(updated_map, 5, 5) == GatType.wall()

      # Other cells should remain unchanged
      assert MapData.get_cell(updated_map, 4, 4) == GatType.walkable()
      assert MapData.get_cell(updated_map, 6, 6) == GatType.walkable()
    end

    test "returns unchanged map for out of bounds", %{map: map} do
      updated_map = MapData.set_cell(map, -1, 0, 1)
      assert updated_map == map

      updated_map = MapData.set_cell(map, 100, 100, 1)
      assert updated_map == map
    end

    test "can set different GAT types", %{map: map} do
      map =
        map
        |> MapData.set_cell(0, 0, GatType.wall())
        |> MapData.set_cell(1, 1, GatType.water())
        |> MapData.set_cell(2, 2, GatType.cliff())

      assert MapData.get_cell(map, 0, 0) == GatType.wall()
      assert MapData.get_cell(map, 1, 1) == GatType.water()
      assert MapData.get_cell(map, 2, 2) == GatType.cliff()
    end
  end

  describe "walkable?/3" do
    setup do
      map =
        MapData.new("test_map", 10, 10)
        # Not walkable
        |> MapData.set_cell(5, 5, GatType.wall())
        # Walkable
        |> MapData.set_cell(6, 6, GatType.walkable())
        # Not walkable
        |> MapData.set_cell(7, 7, GatType.cliff())
        # Walkable
        |> MapData.set_cell(8, 8, GatType.water())

      {:ok, map: map}
    end

    test "returns true for walkable cells", %{map: map} do
      assert MapData.walkable?(map, 6, 6) == true
      assert MapData.walkable?(map, 8, 8) == true
    end

    test "returns false for non-walkable cells", %{map: map} do
      assert MapData.walkable?(map, 5, 5) == false
      assert MapData.walkable?(map, 7, 7) == false
    end

    test "returns false for out of bounds", %{map: map} do
      assert MapData.walkable?(map, -1, 0) == false
      assert MapData.walkable?(map, 100, 100) == false
    end
  end

  describe "blocks_projectile?/3" do
    setup do
      map =
        MapData.new("test_map", 10, 10)
        # Blocks projectiles
        |> MapData.set_cell(5, 5, GatType.wall())
        # Doesn't block
        |> MapData.set_cell(6, 6, GatType.walkable())
        # Doesn't block projectiles
        |> MapData.set_cell(7, 7, GatType.cliff())

      {:ok, map: map}
    end

    test "returns true for cells that block projectiles", %{map: map} do
      assert MapData.blocks_projectile?(map, 5, 5) == true
    end

    test "returns false for cells that don't block projectiles", %{map: map} do
      assert MapData.blocks_projectile?(map, 6, 6) == false
      assert MapData.blocks_projectile?(map, 7, 7) == false
    end

    test "returns true for out of bounds", %{map: map} do
      assert MapData.blocks_projectile?(map, -1, 0) == true
      assert MapData.blocks_projectile?(map, 100, 100) == true
    end
  end

  describe "check_cell/4" do
    setup do
      map =
        MapData.new("test_map", 10, 10)
        |> MapData.set_cell(0, 0, GatType.wall())
        |> MapData.set_cell(1, 1, GatType.water())
        |> MapData.set_cell(2, 2, GatType.cliff())

      {:ok, map: map}
    end

    test "returns correct values for different check types", %{map: map} do
      # Wall checks
      assert MapData.check_cell(map, 0, 0, :chk_wall) == true
      assert MapData.check_cell(map, 1, 1, :chk_wall) == false

      # Water checks
      assert MapData.check_cell(map, 1, 1, :chk_water) == true
      assert MapData.check_cell(map, 0, 0, :chk_water) == false

      # Cliff checks
      assert MapData.check_cell(map, 2, 2, :chk_cliff) == true
      assert MapData.check_cell(map, 0, 0, :chk_cliff) == false

      # Pass checks
      # Walkable
      assert MapData.check_cell(map, 3, 3, :chk_pass) == true
      # Wall
      assert MapData.check_cell(map, 0, 0, :chk_pass) == false
      # Cliff
      assert MapData.check_cell(map, 2, 2, :chk_pass) == false
    end
  end

  describe "set_cell_flag/5" do
    setup do
      map = MapData.new("test_map", 10, 10)
      {:ok, map: map}
    end

    test "sets dynamic flags on cells", %{map: map} do
      updated_map = MapData.set_cell_flag(map, 5, 5, :npc, true)

      # Check that the flag is set
      assert MapData.check_cell(updated_map, 5, 5, :chk_npc) == true
      assert MapData.check_cell(updated_map, 6, 6, :chk_npc) == false
    end

    test "can set multiple flags on the same cell", %{map: map} do
      updated_map =
        map
        |> MapData.set_cell_flag(5, 5, :npc, true)
        |> MapData.set_cell_flag(5, 5, :novending, true)

      assert MapData.check_cell(updated_map, 5, 5, :chk_npc) == true
      assert MapData.check_cell(updated_map, 5, 5, :chk_novending) == true
    end

    test "can remove flags", %{map: map} do
      updated_map =
        map
        |> MapData.set_cell_flag(5, 5, :npc, true)
        |> MapData.set_cell_flag(5, 5, :npc, false)

      assert MapData.check_cell(updated_map, 5, 5, :chk_npc) == false
    end
  end

  describe "load_from_gat_binary/2" do
    test "loads binary GAT data directly" do
      map = MapData.new("test_map", 3, 3)

      gat_binary = <<0, 1, 0, 3, 5, 3, 0, 1, 0>>

      updated_map = MapData.load_from_gat_binary(map, gat_binary)

      assert MapData.get_cell(updated_map, 0, 0) == 0
      assert MapData.get_cell(updated_map, 1, 0) == 1
      assert MapData.get_cell(updated_map, 0, 1) == 3
      assert MapData.get_cell(updated_map, 1, 1) == 5
    end

    test "returns unchanged map if binary size doesn't match" do
      map = MapData.new("test_map", 3, 3)

      # Wrong size binary
      gat_binary = <<0, 1, 0>>

      updated_map = MapData.load_from_gat_binary(map, gat_binary)
      assert updated_map == map
    end
  end
end
