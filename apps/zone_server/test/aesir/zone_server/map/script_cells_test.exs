defmodule Aesir.ZoneServer.Map.ScriptCellsTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.ScriptCells

  setup :setup_ets_tables

  setup do
    map =
      MapData.new("script_cells_test", 10, 10)
      |> MapData.set_cell(5, 5, GatType.wall())

    :ets.insert(EtsTable.table_for(:map_cache), {"script_cells_test", map})
    {:ok, map: map}
  end

  test "set/5 blocks walkable cells and clear restores them" do
    assert Cell.traversable?("script_cells_test", 0, 0)

    :ok = ScriptCells.set("script_cells_test", {0, 0}, {2, 2}, :walkable, 0)
    refute Cell.traversable?("script_cells_test", 0, 0)
    refute Cell.traversable?("script_cells_test", 2, 2)

    :ok = ScriptCells.set("script_cells_test", {0, 0}, {2, 2}, :walkable, 1)
    assert Cell.traversable?("script_cells_test", 0, 0)
  end

  test "set/5 toggles shootable and icewall traits" do
    :ok = ScriptCells.set("script_cells_test", {0, 0}, {1, 1}, :shootable, 0)
    assert Cell.blocks_projectiles?("script_cells_test", 0, 0)

    :ok = ScriptCells.set("script_cells_test", {0, 0}, {1, 1}, :shootable, 1)
    refute Cell.blocks_projectiles?("script_cells_test", 0, 0)

    :ok = ScriptCells.set("script_cells_test", {0, 0}, {1, 1}, :icewall, 1)
    assert Cell.icewall?("script_cells_test", 0, 0)

    :ok = ScriptCells.set("script_cells_test", {0, 0}, {1, 1}, :icewall, 0)
    refute Cell.icewall?("script_cells_test", 0, 0)
  end

  test "set/5 normalizes reversed corners" do
    :ok = ScriptCells.set("script_cells_test", {2, 2}, {0, 0}, :icewall, 1)

    assert Cell.icewall?("script_cells_test", 0, 0)
    assert Cell.icewall?("script_cells_test", 1, 1)
    assert Cell.icewall?("script_cells_test", 2, 2)
  end

  test "set/5 skips out-of-bounds cells with a warning" do
    log =
      capture_log(fn ->
        :ok = ScriptCells.set("script_cells_test", {8, 8}, {12, 12}, :icewall, 1)
      end)

    assert log =~ "out-of-bounds"
    assert Cell.icewall?("script_cells_test", 9, 9)
    refute Cell.icewall?("script_cells_test", 10, 10)
  end

  test "set/5 warns and changes nothing on a base-unwalkable restore" do
    log =
      capture_log(fn ->
        :ok = ScriptCells.set("script_cells_test", {5, 5}, {5, 5}, :walkable, 1)
      end)

    assert log =~ "base-unwalkable"
    refute Cell.traversable?("script_cells_test", 5, 5)
  end

  test "set/5 warns and no-ops on unknown type and unknown map" do
    log =
      capture_log(fn ->
        :ok = ScriptCells.set("script_cells_test", {0, 0}, {1, 1}, :basilica, 1)
        :ok = ScriptCells.set("missing_map", {0, 0}, {1, 1}, :icewall, 1)
      end)

    assert log =~ "setcell ignored"
    refute Cell.icewall?("script_cells_test", 0, 0)
  end

  test "set/5 is idempotent for repeated identical calls" do
    :ok = ScriptCells.set("script_cells_test", {0, 0}, {2, 2}, :icewall, 1)
    :ok = ScriptCells.set("script_cells_test", {0, 0}, {2, 2}, :icewall, 1)

    assert Cell.icewall?("script_cells_test", 0, 0)

    contribution_index = EtsTable.table_for(:dynamic_cell_contributions)

    assert :ets.lookup(contribution_index, {"script_cells_test", 0, 0, :npc_script, 0}) == [
             {{"script_cells_test", 0, 0, :npc_script, 0}, %{icewall: true}}
           ]
  end
end
