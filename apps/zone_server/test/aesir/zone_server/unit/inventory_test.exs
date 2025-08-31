defmodule Aesir.ZoneServer.Unit.InventoryTest do
  use Aesir.DataCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Inventory

  describe "inventory management" do
    setup do
      # Create test account and character
      {:ok, account} =
        %Account{}
        |> Account.changeset(%{
          username: "testuser",
          userid: "testuser",
          user_pass: "password",
          email: "test@test.com"
        })
        |> Repo.insert()

      {:ok, character} =
        %Character{}
        |> Character.changeset(%{
          account_id: account.id,
          char_num: 0,
          name: "TestChar",
          class: 1
        })
        |> Repo.insert()

      %{account: account, character: character}
    end

    test "loads empty inventory for new character", %{character: character} do
      {:ok, items} = Inventory.load_inventory(character.id)
      assert items == []
    end

    test "adds item to inventory", %{character: character} do
      # Add a Red Potion (item ID 501)
      {:ok, item} = Inventory.add_item(character.id, 501, 5)

      assert item.char_id == character.id
      assert item.nameid == 501
      assert item.amount == 5
      assert item.unique_id > 0
    end

    test "stacks identical items", %{character: character} do
      # Add first batch
      {:ok, item1} = Inventory.add_item(character.id, 501, 5)

      # Add second batch - should stack
      {:ok, item2} = Inventory.add_item(character.id, 501, 3)

      # Should be the same item with combined amount
      assert item1.id == item2.id
      assert item2.amount == 8
    end

    test "removes item from inventory", %{character: character} do
      # Add item
      {:ok, item} = Inventory.add_item(character.id, 501, 10)

      # Remove some
      {:ok, updated_item} = Inventory.remove_item(character.id, item.id, 3)
      assert updated_item.amount == 7

      # Remove all remaining
      {:ok, _deleted_item} = Inventory.remove_item(character.id, item.id, 7)

      # Should be gone
      assert {:error, :item_not_found} = Inventory.get_item(character.id, item.id)
    end

    test "equips and unequips items", %{character: character} do
      # Add a sword (assuming item ID 1201)
      {:ok, item} = Inventory.add_item(character.id, 1201, 1)

      # Equip it (position 2 = right hand)
      {:ok, equipped_item} = Inventory.equip_item(character.id, item.id, 2)
      assert equipped_item.equip == 2

      # Unequip it
      {:ok, unequipped_item} = Inventory.unequip_item(character.id, item.id)
      assert unequipped_item.equip == 0
    end

    test "gets equipped items", %{character: character} do
      # Add and equip multiple items
      {:ok, sword} = Inventory.add_item(character.id, 1201, 1)
      {:ok, armor} = Inventory.add_item(character.id, 2301, 1)

      {:ok, _} = Inventory.equip_item(character.id, sword.id, 2)
      {:ok, _} = Inventory.equip_item(character.id, armor.id, 16)

      {:ok, equipped_items} = Inventory.get_equipped_items(character.id)
      assert length(equipped_items) == 2
    end

    test "handles inventory errors gracefully", %{character: character} do
      # Try to get non-existent item
      assert {:error, :item_not_found} = Inventory.get_item(character.id, 99_999)

      # Try to remove more items than available
      {:ok, item} = Inventory.add_item(character.id, 501, 5)
      assert {:error, :insufficient_amount} = Inventory.remove_item(character.id, item.id, 10)
    end
  end
end
