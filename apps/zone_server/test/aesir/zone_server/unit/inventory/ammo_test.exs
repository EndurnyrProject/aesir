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

  describe "equipped_ammo/1" do
    test "returns the equipped row and its item definition without changing inventory" do
      ammo = item(1771, 3, @ammo_bit)
      inventory = %{1 => ammo}

      assert {:ok, ^ammo, definition} = Ammo.equipped_ammo(inventory)
      assert definition.id == 1771
      assert definition.attack == 30
      assert inventory == %{1 => ammo}
    end
  end

  describe "check/3" do
    test "accepts an equipped ammunition of an allowed subtype with enough units" do
      assert :ok = Ammo.check(%{1 => item(1750, 30, @ammo_bit)}, [:arrow], 5)
    end

    test "accepts a stack holding exactly the required units" do
      assert :ok = Ammo.check(%{1 => item(1750, 5, @ammo_bit)}, [:arrow], 5)
    end

    test "refuses a foreign ammunition subtype" do
      assert {:error, :no_ammo} = Ammo.check(%{1 => item(1771, 30, @ammo_bit)}, [:arrow], 1)
    end

    test "refuses a stack shorter than the required units" do
      assert {:error, :no_ammo} = Ammo.check(%{1 => item(1750, 4, @ammo_bit)}, [:arrow], 5)
    end

    test "refuses an empty ammo slot" do
      assert {:error, :no_ammo} = Ammo.check(%{}, [:arrow], 1)
      assert {:error, :no_ammo} = Ammo.check(%{1 => item(1750, 30, 0)}, [:arrow], 1)
    end
  end

  describe "consume/2" do
    test "removes the given amount from the equipped ammo stack" do
      inventory = %{1 => item(1750, 30, @ammo_bit)}

      assert {:ok, new_inventory, {:reduced, 1, 25}} = Ammo.consume(inventory, 5)
      assert new_inventory[1].amount == 25
    end

    test "drops the slot when the stack holds exactly the consumed amount" do
      assert {:ok, new_inventory, {:removed, 1}} =
               Ammo.consume(%{1 => item(1750, 5, @ammo_bit)}, 5)

      refute Map.has_key?(new_inventory, 1)
    end

    test "refuses a stack shorter than the consumed amount without changing it" do
      inventory = %{1 => item(1750, 4, @ammo_bit)}

      assert {:error, :insufficient_amount} = Ammo.consume(inventory, 5)
      assert inventory[1].amount == 4
    end

    test "refuses an empty ammo slot" do
      assert {:error, :no_ammo} = Ammo.consume(%{}, 1)
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
