defmodule Aesir.ZoneServer.Mmo.Skill.Unit.CellTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell

  test "builds a destructible targetable cell with stable flags" do
    assert {:ok, cell} =
             Cell.new(%{
               cell_id: 1,
               group_id: 2,
               map_name: "prontera",
               x: 100,
               y: 101,
               hp: 400,
               max_hp: 400,
               flags: [:targetable, :blocks_movement, :visible]
             })

    assert cell.flags == (Cell.targetable() ||| Cell.blocks_movement() ||| Cell.visible())
    assert Cell.flag?(cell, :targetable)
    assert Cell.flag?(cell, :blocks_movement)
    refute Cell.flag?(cell, :consumable_water)
  end

  test "rejects invalid hit point and flag combinations" do
    attrs = %{cell_id: 1, group_id: 2, map_name: "map", x: 0, y: 0}
    assert {:error, :invalid_hp} = Cell.new(Map.merge(attrs, %{hp: 1, max_hp: 0}))
    assert {:error, :invalid_flags} = Cell.new(Map.put(attrs, :flags, [:unknown]))
  end

  test "rejects malformed identity, coordinates, and state" do
    assert {:error, :invalid_cell} =
             Cell.new(%{cell_id: 0, group_id: 1, map_name: "map", x: 0, y: 0})

    assert {:error, :invalid_cell} =
             Cell.new(%{cell_id: 1, group_id: 1, map_name: "", x: 0, y: 0})

    assert {:error, :invalid_cell} =
             Cell.new(%{cell_id: 1, group_id: 1, map_name: "map", x: -1, y: 0})

    assert {:error, :invalid_cell} =
             Cell.new(%{cell_id: 1, group_id: 1, map_name: "map", x: 0, y: 0, state: :bad})
  end

  test "rejects non-integer and out-of-range group ids" do
    base = %{cell_id: 1, map_name: "map", x: 0, y: 0}

    for group_id <- [:group, 1.5, -1, 0, 0x1_0000_0000_0000_0000] do
      assert {:error, :invalid_cell} = Cell.new(Map.put(base, :group_id, group_id))
    end
  end
end
