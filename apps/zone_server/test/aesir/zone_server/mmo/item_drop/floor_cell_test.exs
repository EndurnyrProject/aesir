defmodule Aesir.ZoneServer.Mmo.ItemDrop.FloorCellTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemDrop.FloorCell

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"floor", MapData.new("floor", 100, 100)})
    :ok
  end

  test "lands on a neighbour, never the target, in the order the mirrors pick" do
    keep = fn _bound -> 1 end
    flip = fn _bound -> 2 end

    assert FloorCell.around("floor", 50, 50, keep) == {49, 49}
    assert FloorCell.around("floor", 50, 50, flip) == {51, 51}
  end

  test "skips blocked cells and cells near the edge, falling back to the target" do
    :ok = Cell.put("floor", 49, 49, :test_blocker, 1, blocks_movement: true)
    assert FloorCell.around("floor", 50, 50, fn _ -> 1 end) == {49, 50}

    assert FloorCell.around("floor", 5, 5, fn _ -> 1 end) == {5, 6}
    assert FloorCell.around("floor", 4, 3, fn _ -> 1 end) == {4, 3}
  end
end
