defmodule Aesir.ZoneServer.Unit.TradeTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Trade

  test "rejects equipped items" do
    assert Trade.offerable?(item(equip: 1), item_definition()) == {:error, :equipped}
  end

  test "prioritizes equipped items over other rejection reasons" do
    assert Trade.offerable?(
             item(equip: 1, bound: 1, expire_time: ~N[2026-08-10 12:00:00]),
             item_definition(no_trade: true)
           ) == {:error, :equipped}
  end

  test "rejects bound items" do
    for bound <- 1..4 do
      assert Trade.offerable?(item(bound: bound), item_definition()) == {:error, :bound}
    end
  end

  test "rejects rented items" do
    assert Trade.offerable?(item(expire_time: ~N[2026-08-10 12:00:00]), item_definition()) ==
             {:error, :rented}
  end

  test "rejects items marked no_trade" do
    assert Trade.offerable?(item(), item_definition(no_trade: true)) == {:error, :no_trade}
  end

  test "allows a clean item" do
    assert Trade.offerable?(item(), item_definition()) == :ok
  end

  defp item(attrs \\ []) do
    struct!(InventoryItem, attrs)
  end

  defp item_definition(attrs \\ []) do
    struct!(ItemDefinition, [id: 1, aegis_name: "TestItem", name: "Test Item"] ++ attrs)
  end
end
