defmodule Aesir.ZoneServer.Unit.Inventory.AmmoTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Ammo

  @ammo_bit 0x008000
  @armor_bit 0x000010

  defp item(nameid, amount, equip),
    do: %InventoryItem{nameid: nameid, amount: amount, equip: equip}

  describe "equipped_ammo_index/1" do
    test "returns the index of the item equipped in the ammo slot" do
      inventory = %{
        0 => item(2301, 1, @armor_bit),
        1 => item(1750, 30, @ammo_bit)
      }

      assert Ammo.equipped_ammo_index(inventory) == 1
    end

    test "returns nil when no item is equipped in the ammo slot" do
      inventory = %{
        0 => item(2301, 1, @armor_bit),
        1 => item(1750, 30, 0)
      }

      assert Ammo.equipped_ammo_index(inventory) == nil
    end

    test "returns nil for an empty inventory" do
      assert Ammo.equipped_ammo_index(%{}) == nil
    end
  end

  describe "consume_one/1" do
    test "decrements the equipped ammo stack by one" do
      inventory = %{1 => item(1750, 30, @ammo_bit)}

      assert {:ok, new_inventory, {:reduced, 1, 29}} = Ammo.consume_one(inventory)
      assert new_inventory[1].amount == 29
    end

    test "removes the slot when the stack reaches zero" do
      inventory = %{1 => item(1750, 1, @ammo_bit)}

      assert {:ok, new_inventory, {:removed, 1}} = Ammo.consume_one(inventory)
      refute Map.has_key?(new_inventory, 1)
    end

    test "returns :no_ammo when nothing is equipped in the ammo slot" do
      assert {:error, :no_ammo} = Ammo.consume_one(%{})
      assert {:error, :no_ammo} = Ammo.consume_one(%{0 => item(1750, 30, 0)})
    end
  end
end
