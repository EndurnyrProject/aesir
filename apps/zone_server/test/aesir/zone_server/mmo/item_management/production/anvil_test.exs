defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.AnvilTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Anvil

  test "selects the highest anvil grade in the inventory" do
    inventory = %{
      0 => %InventoryItem{nameid: 986, amount: 1},
      1 => %InventoryItem{nameid: 987, amount: 1},
      2 => %InventoryItem{nameid: 988, amount: 1},
      3 => %InventoryItem{nameid: 989, amount: 1}
    }

    assert 1000 = Anvil.best(inventory)
  end

  test "returns each anvil grade bonus" do
    for {item_id, bonus} <- [{986, 0}, {987, 250}, {988, 500}, {989, 1000}] do
      assert ^bonus = Anvil.best(%{0 => %InventoryItem{nameid: item_id, amount: 1}})
    end
  end

  test "returns zero without an anvil" do
    assert 0 = Anvil.best(%{0 => %InventoryItem{nameid: 501, amount: 1}})
  end

  test "does not consume the selected anvil" do
    inventory = %{0 => %InventoryItem{nameid: 989, amount: 1}}

    assert 1000 = Anvil.best(inventory)
    assert %{0 => %InventoryItem{nameid: 989, amount: 1}} = inventory
  end
end
