defmodule Aesir.ZoneServer.Unit.Inventory.PersistenceTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Persistence

  setup do
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

  describe "load_inventory/1" do
    test "returns an empty list for a character with no items", %{character: character} do
      assert {:ok, []} = Persistence.load_inventory(character.id)
    end

    test "returns items ordered by id", %{character: character} do
      {:ok, first} = Persistence.insert_item(character.id, %{nameid: 501, amount: 1})
      {:ok, second} = Persistence.insert_item(character.id, %{nameid: 1201, amount: 1})

      assert {:ok, [%InventoryItem{id: first_id}, %InventoryItem{id: second_id}]} =
               Persistence.load_inventory(character.id)

      assert first_id == first.id
      assert second_id == second.id
    end

    test "only returns items for the given character", %{character: character} do
      {:ok, other_account} =
        %Account{}
        |> Account.changeset(%{
          username: "other",
          userid: "other",
          user_pass: "password",
          email: "other@test.com"
        })
        |> Repo.insert()

      {:ok, other_character} =
        %Character{}
        |> Character.changeset(%{
          account_id: other_account.id,
          char_num: 0,
          name: "OtherChar",
          class: 1
        })
        |> Repo.insert()

      {:ok, _} = Persistence.insert_item(character.id, %{nameid: 501, amount: 1})
      {:ok, _} = Persistence.insert_item(other_character.id, %{nameid: 1201, amount: 1})

      assert {:ok, [%InventoryItem{nameid: 501}]} = Persistence.load_inventory(character.id)
    end
  end

  describe "insert_item/2" do
    test "inserts a valid item", %{character: character} do
      assert {:ok, %InventoryItem{id: id, nameid: 501, amount: 5}} =
               Persistence.insert_item(character.id, %{nameid: 501, amount: 5})

      assert is_integer(id)
    end

    test "returns the changeset error on invalid attrs", %{character: character} do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Persistence.insert_item(character.id, %{nameid: 501, amount: 1, refine: 99})
    end
  end

  describe "update_item/2" do
    test "updates an existing item", %{character: character} do
      {:ok, item} = Persistence.insert_item(character.id, %{nameid: 501, amount: 5})

      assert {:ok, %InventoryItem{amount: 10}} = Persistence.update_item(item, %{amount: 10})
    end

    test "returns the changeset error on invalid update", %{character: character} do
      {:ok, item} = Persistence.insert_item(character.id, %{nameid: 501, amount: 5})

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Persistence.update_item(item, %{refine: 99})
    end
  end

  describe "delete_item/1" do
    test "deletes an existing item", %{character: character} do
      {:ok, item} = Persistence.insert_item(character.id, %{nameid: 501, amount: 5})

      assert {:ok, %InventoryItem{}} = Persistence.delete_item(item)
      assert {:ok, []} = Persistence.load_inventory(character.id)
    end
  end

  describe "transaction/1" do
    test "commits all writes when the function returns {:ok, _}", %{character: character} do
      result =
        Persistence.transaction(fn ->
          {:ok, _} = Persistence.insert_item(character.id, %{nameid: 501, amount: 1})
          {:ok, _} = Persistence.insert_item(character.id, %{nameid: 1201, amount: 1})
          {:ok, :done}
        end)

      assert {:ok, :done} = result
      assert {:ok, [_, _]} = Persistence.load_inventory(character.id)
    end

    test "rolls back all writes when the function returns {:error, _}", %{character: character} do
      result =
        Persistence.transaction(fn ->
          {:ok, _} = Persistence.insert_item(character.id, %{nameid: 501, amount: 1})
          {:error, :boom}
        end)

      assert {:error, :boom} = result
      assert {:ok, []} = Persistence.load_inventory(character.id)
    end
  end
end
