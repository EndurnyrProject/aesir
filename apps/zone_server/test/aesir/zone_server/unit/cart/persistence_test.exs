defmodule Aesir.ZoneServer.Unit.Cart.PersistenceTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Cart.Persistence

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

  describe "load_cart/1" do
    test "returns an empty list for a character with no items", %{character: character} do
      assert {:ok, []} = Persistence.load_cart(character.id)
    end

    test "returns items ordered by id", %{character: character} do
      {:ok, first} = Persistence.insert_item(character.id, %{nameid: 501, amount: 1})
      {:ok, second} = Persistence.insert_item(character.id, %{nameid: 1201, amount: 1})

      assert {:ok, [%CartItem{id: first_id}, %CartItem{id: second_id}]} =
               Persistence.load_cart(character.id)

      assert first_id == first.id
      assert second_id == second.id
    end
  end

  describe "insert_item/2" do
    test "inserts a valid item carrying its db id", %{character: character} do
      assert {:ok, %CartItem{id: id, nameid: 501, amount: 5}} =
               Persistence.insert_item(character.id, %{nameid: 501, amount: 5})

      assert is_integer(id)
    end
  end

  describe "update_item/2" do
    test "updates the amount of an existing item", %{character: character} do
      {:ok, item} = Persistence.insert_item(character.id, %{nameid: 501, amount: 5})

      assert {:ok, %CartItem{amount: 10}} = Persistence.update_item(item, %{amount: 10})
    end
  end

  describe "delete_item/1" do
    test "deletes an existing item", %{character: character} do
      {:ok, item} = Persistence.insert_item(character.id, %{nameid: 501, amount: 5})

      assert {:ok, %CartItem{}} = Persistence.delete_item(item)
      assert {:ok, []} = Persistence.load_cart(character.id)
    end
  end
end
