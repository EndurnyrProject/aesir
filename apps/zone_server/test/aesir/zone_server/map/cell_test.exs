defmodule Aesir.ZoneServer.Map.CellTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData

  setup :setup_ets_tables

  setup do
    map =
      MapData.new("cell_test", 3, 3)
      |> MapData.set_cell(1, 0, GatType.wall())
      |> MapData.set_cell(2, 0, GatType.water())

    :ets.insert(EtsTable.table_for(:map_cache), {"cell_test", map})
    {:ok, map: map}
  end

  test "reads immutable base traversal, projectile, placement, and water properties" do
    assert Cell.traversable?("cell_test", 0, 0)
    refute Cell.traversable?("cell_test", 1, 0)
    assert Cell.blocks_projectiles?("cell_test", 1, 0)
    refute Cell.blocks_projectiles?("cell_test", 0, 0)
    assert Cell.placeable?("cell_test", 0, 0)
    refute Cell.placeable?("cell_test", 1, 0)
    assert %Cell.WaterSource{origin: :base, cell_id: nil} = Cell.water_source("cell_test", 2, 0)
    assert Cell.water_source("cell_test", 0, 0) == nil
  end

  test "merges independent source contributions and restores exact base terrain", %{map: map} do
    :ok = Cell.put("cell_test", 0, 0, :icewall, 1, blocks_movement: true)
    :ok = Cell.put("cell_test", 0, 0, :barrier, 2, blocks_projectiles: true)

    refute Cell.traversable?("cell_test", 0, 0)
    assert Cell.blocks_projectiles?("cell_test", 0, 0)
    refute Cell.placeable?("cell_test", 0, 0)

    :ok = Cell.delete("cell_test", 0, 0, :icewall, 1)
    assert Cell.traversable?("cell_test", 0, 0)
    assert Cell.blocks_projectiles?("cell_test", 0, 0)

    :ok = Cell.delete("cell_test", 0, 0, :barrier, 2)
    assert Cell.traversable?("cell_test", 0, 0)
    refute Cell.blocks_projectiles?("cell_test", 0, 0)
    assert MapCache.get!("cell_test") == map
  end

  test "distinguishes consumable skill water from permanent base water" do
    :ok = Cell.put("cell_test", 0, 1, :deluge, 42, consumable_water: 42)

    assert %Cell.WaterSource{origin: :skill_unit, cell_id: 42} =
             Cell.water_source("cell_test", 0, 1)

    assert %Cell.WaterSource{origin: :base, cell_id: nil} = Cell.water_source("cell_test", 2, 0)
  end

  test "detects only Ice Wall overlap" do
    :ok = Cell.put("cell_test", 0, 0, :barrier, 1, blocks_movement: true)
    refute Cell.ice_wall_overlap?("cell_test", 0, 0)

    :ok = Cell.put("cell_test", 0, 0, :icewall, 2, blocks_movement: true)
    assert Cell.ice_wall_overlap?("cell_test", 0, 0)
  end

  test "canonicalizes .gat aliases for contributions and lookups" do
    :ok = Cell.put("cell_test.gat", 0, 0, :barrier, 1, blocks_movement: true)

    refute Cell.traversable?("cell_test", 0, 0)
    refute Cell.traversable?("cell_test.gat", 0, 0)

    :ok = Cell.delete("cell_test", 0, 0, :barrier, 1)
    assert Cell.traversable?("cell_test.gat", 0, 0)
  end

  test "samples canonical map aliases and rejects exhausted or non-positive attempt budgets" do
    :ets.insert(EtsTable.table_for(:map_cache), {"single_cell", MapData.new("single_cell", 1, 1)})

    assert {:ok, {0, 0}} = Cell.random_traversable("single_cell.gat", 1)
    assert {:error, :no_walkable_cell} = Cell.random_traversable("single_cell", 0)
    assert {:error, :no_walkable_cell} = Cell.random_traversable("single_cell", -1)

    :ok = Cell.put("single_cell", 0, 0, :test_blocker, 1, blocks_movement: true)
    assert {:error, :no_walkable_cell} = Cell.random_traversable("single_cell", 1)
  end

  test "requires a valid base coordinate for dynamic water and validates its cell ID" do
    :ok = Cell.put("missing", 0, 0, :deluge, 1, consumable_water: 1)
    :ok = Cell.put("cell_test", 99, 99, :deluge, 2, consumable_water: 2)

    assert Cell.water_source("missing", 0, 0) == nil
    assert Cell.water_source("cell_test", 99, 99) == nil

    assert_raise ArgumentError, fn ->
      Cell.put("cell_test", 0, 0, :deluge, 0, consumable_water: 0)
    end

    assert_raise ArgumentError, fn ->
      Cell.put("cell_test", 0, 0, :deluge, 1, consumable_water: 0x1_0000_0000)
    end
  end

  test "keeps source and coordinate indexes consistent through replacements and concurrent cleanup" do
    :ok = Cell.put("cell_test", 0, 0, :skill_unit, 9, blocks_movement: true)
    :ok = Cell.put("cell_test", 0, 1, :skill_unit, 9, blocks_projectiles: true)
    :ok = Cell.put("cell_test", 0, 0, :skill_unit, 9, blocks_projectiles: true)

    source_index = EtsTable.table_for(:dynamic_cell_source_index)
    contribution_index = EtsTable.table_for(:dynamic_cell_contributions)

    assert :ets.lookup(source_index, {:skill_unit, 9}) |> length() == 2

    assert :ets.lookup(contribution_index, {"cell_test", 0, 0, :skill_unit, 9}) == [
             {{"cell_test", 0, 0, :skill_unit, 9}, %{blocks_projectiles: true}}
           ]

    1..20
    |> Task.async_stream(fn _ -> Cell.put("cell_test.gat", 0, 0, :skill_unit, 10, []) end)
    |> Enum.each(fn {:ok, :ok} -> :ok end)

    [
      fn -> Cell.delete_source(:skill_unit, 9) end,
      fn -> Cell.delete_source(:skill_unit, 10) end,
      &Cell.clear/0
    ]
    |> Task.async_stream(& &1.())
    |> Enum.each(fn {:ok, :ok} -> :ok end)

    assert [] == :ets.tab2list(source_index)
    assert [] == :ets.tab2list(contribution_index)
  end
end
