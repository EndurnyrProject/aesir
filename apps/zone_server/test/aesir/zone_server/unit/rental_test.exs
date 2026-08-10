defmodule Aesir.ZoneServer.Unit.RentalTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Rental

  @now ~N[2026-08-10 12:00:00]

  test "identifies items with an expiry as rented" do
    refute Rental.rented?(item())
    assert Rental.rented?(item(expire_time: ~N[2026-08-10 12:00:01]))
  end

  test "expires rented items at their expiry boundary" do
    assert Rental.expired?(item(), @now) == false
    assert Rental.expired?(item(expire_time: ~N[2026-08-10 12:00:01]), @now) == false
    assert Rental.expired?(item(expire_time: ~N[2026-08-10 12:00:00]), @now)
    assert Rental.expired?(item(expire_time: ~N[2026-08-10 11:59:59]), @now)
  end

  test "allows transfers only for items that are not rented" do
    assert Rental.transferable?(item())
    refute Rental.transferable?(item(expire_time: ~N[2026-08-10 12:00:01]))
  end

  test "allows rentals only for equipment types" do
    for type <- [:weapon, :armor, :pet_armor, :shadow_gear] do
      assert Rental.rentable_type?(item_definition(type))
    end

    for type <- [:healing, :usable, :etc, :card, :ammo, :cash, :pet_egg, :delay_consume] do
      refute Rental.rentable_type?(item_definition(type))
    end
  end

  test "calculates an expiry from a duration in seconds" do
    assert Rental.expire_at(90, @now) == ~N[2026-08-10 12:01:30]
  end

  defp item(attrs \\ []) do
    struct!(InventoryItem, attrs)
  end

  defp item_definition(type) do
    %ItemDefinition{id: 1, aegis_name: "TestItem", name: "Test Item", type: type}
  end
end
