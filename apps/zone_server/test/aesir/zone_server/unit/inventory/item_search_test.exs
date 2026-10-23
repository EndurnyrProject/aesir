defmodule Aesir.ZoneServer.Unit.Inventory.ItemSearchTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Unit.Inventory.ItemSearch

  @potion 501
  @stone 7049

  defp row(nameid, amount, fields \\ []),
    do: struct!(%InventoryItem{nameid: nameid, amount: amount, identify: 1}, fields)

  defp exact(fields),
    do:
      Map.merge(
        %{
          nameid: @stone,
          identify: 1,
          refine: 0,
          attribute: 0,
          enchant_grade: 0,
          cards: [0, 0, 0, 0],
          options: nil
        },
        Map.new(fields)
      )

  describe "count/3" do
    test "counts every non-rental row of the item, worn, refined or carded" do
      inventory = %{
        0 => row(@potion, 2),
        1 => row(@potion, 1, equip: 2, refine: 4, card0: 4001),
        2 => row(@potion, 5, expire_time: ~N[2030-01-01 00:00:00]),
        3 => row(502, 9)
      }

      assert ItemSearch.count(inventory, @potion) == 3
    end

    test "an exact count compares a signed item by its card values" do
      signed = ItemCraft.to_map(ItemCraft.signed(150_001))
      inventory = %{0 => row(@stone, 1, craft: signed), 1 => row(@stone, 4)}

      cards = [254, 0, 150_001 &&& 0xFFFF, 150_001 >>> 16]
      assert ItemSearch.count(inventory, exact(cards: cards)) == 1
      assert ItemSearch.count(inventory, exact([])) == 4
    end
  end

  describe "delete_plan/3" do
    test "takes plain unequipped rows first, then any other row of the item" do
      inventory = %{
        0 => row(@potion, 1, equip: 2),
        1 => row(@potion, 2),
        2 => row(@potion, 1, refine: 3)
      }

      assert ItemSearch.delete_plan(inventory, @potion, 3) == {:ok, [{1, 2}, {0, 1}]}
    end

    test "a short count deletes nothing" do
      assert ItemSearch.delete_plan(%{0 => row(@potion, 2)}, @potion, 3) == {:error, []}
    end

    test "the counting run counts first-pass rows again, so the deleting run can fall short" do
      inventory = %{0 => row(@potion, 2), 1 => row(@potion, 1, refine: 3)}

      assert ItemSearch.delete_plan(inventory, @potion, 4) == {:error, [{0, 2}, {1, 1}]}
    end

    test "an exact delete skips rows with other attributes" do
      inventory = %{0 => row(@stone, 1, identify: 0), 1 => row(@stone, 2)}

      assert ItemSearch.delete_plan(inventory, exact([]), 1) == {:ok, [{1, 1}]}
      assert ItemSearch.delete_plan(inventory, exact(identify: 0), 2) == {:error, []}
    end
  end

  test "a forged item's card values carry its element and star crumbs" do
    craft = ItemCraft.forged(:fire, 2, 7)
    assert ItemCraft.card_words(craft) == [255, (10 <<< 8) + 3, 7, 0]
  end
end
