defmodule Aesir.ZoneServer.Unit.Storage.PersistenceTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.StorageItem
  alias Aesir.ZoneServer.Unit.Storage.Persistence

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

    %{account: account}
  end

  describe "load_storage/1" do
    test "returns an empty list for an account with no items", %{account: account} do
      assert [] = Persistence.load_storage(account.id)
    end

    test "returns items ordered by id", %{account: account} do
      {:ok, first} = Persistence.insert_item(account.id, %{nameid: 501, amount: 1})
      {:ok, second} = Persistence.insert_item(account.id, %{nameid: 1201, amount: 1})

      assert [%StorageItem{id: first_id}, %StorageItem{id: second_id}] =
               Persistence.load_storage(account.id)

      assert first_id == first.id
      assert second_id == second.id
    end

    test "only returns items for the given account", %{account: account} do
      {:ok, other_account} =
        %Account{}
        |> Account.changeset(%{
          username: "other",
          userid: "other",
          user_pass: "password",
          email: "other@test.com"
        })
        |> Repo.insert()

      {:ok, _} = Persistence.insert_item(account.id, %{nameid: 501, amount: 1})
      {:ok, _} = Persistence.insert_item(other_account.id, %{nameid: 1201, amount: 1})

      assert [%StorageItem{nameid: 501}] = Persistence.load_storage(account.id)
    end
  end

  describe "insert_item/2" do
    test "inserts a valid item carrying its db id", %{account: account} do
      assert {:ok, %StorageItem{id: id, nameid: 501, amount: 5}} =
               Persistence.insert_item(account.id, %{nameid: 501, amount: 5})

      assert is_integer(id)
    end

    test "returns the changeset error on invalid attrs", %{account: account} do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Persistence.insert_item(account.id, %{nameid: 501, amount: 1, refine: 99})
    end
  end

  describe "update_item/2" do
    test "updates the amount of an existing item", %{account: account} do
      {:ok, item} = Persistence.insert_item(account.id, %{nameid: 501, amount: 5})

      assert {:ok, %StorageItem{amount: 10}} = Persistence.update_item(item, %{amount: 10})
    end

    test "returns the changeset error on invalid update", %{account: account} do
      {:ok, item} = Persistence.insert_item(account.id, %{nameid: 501, amount: 5})

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Persistence.update_item(item, %{refine: 99})
    end
  end

  describe "delete_item/1" do
    test "deletes an existing item", %{account: account} do
      {:ok, item} = Persistence.insert_item(account.id, %{nameid: 501, amount: 5})

      assert {:ok, %StorageItem{}} = Persistence.delete_item(item)
      assert [] = Persistence.load_storage(account.id)
    end
  end

  describe "transaction/1" do
    test "commits all writes when the function returns {:ok, _}", %{account: account} do
      result =
        Persistence.transaction(fn ->
          {:ok, _} = Persistence.insert_item(account.id, %{nameid: 501, amount: 1})
          {:ok, _} = Persistence.insert_item(account.id, %{nameid: 1201, amount: 1})
          {:ok, :done}
        end)

      assert {:ok, :done} = result
      assert [_, _] = Persistence.load_storage(account.id)
    end

    test "rolls back all writes when the function returns {:error, _}", %{account: account} do
      result =
        Persistence.transaction(fn ->
          {:ok, _} = Persistence.insert_item(account.id, %{nameid: 501, amount: 1})
          {:error, :boom}
        end)

      assert {:error, :boom} = result
      assert [] = Persistence.load_storage(account.id)
    end
  end

  describe "to_session_item/1 and to_storage_row/2" do
    test "round-trips every column, including unique_id, enchant_grade, and expire_time", %{
      account: account
    } do
      expire_time = ~N[2027-01-01 00:00:00]

      {:ok, row} =
        Persistence.insert_item(account.id, %{
          nameid: 501,
          amount: 3,
          identify: 1,
          refine: 7,
          attribute: 1,
          card0: 4001,
          card1: 4002,
          card2: 4003,
          card3: 4004,
          random_options: %{"1" => %{"val" => 5, "parm" => 0}},
          expire_time: expire_time,
          bound: 1,
          unique_id: 123_456_789,
          enchant_grade: 3
        })

      session_item = Persistence.to_session_item(row)

      assert %InventoryItem{
               id: id,
               nameid: 501,
               amount: 3,
               equip: 0,
               identify: 1,
               refine: 7,
               attribute: 1,
               card0: 4001,
               card1: 4002,
               card2: 4003,
               card3: 4004,
               expire_time: ^expire_time,
               bound: 1,
               unique_id: 123_456_789,
               enchant_grade: 3
             } = session_item

      assert id == row.id
      assert session_item.random_options == row.random_options

      storage_row = Persistence.to_storage_row(session_item, account.id)

      assert %StorageItem{
               id: ^id,
               account_id: account_id,
               nameid: 501,
               amount: 3,
               identify: 1,
               refine: 7,
               attribute: 1,
               card0: 4001,
               card1: 4002,
               card2: 4003,
               card3: 4004,
               expire_time: ^expire_time,
               bound: 1,
               unique_id: 123_456_789,
               enchant_grade: 3
             } = storage_row

      assert account_id == account.id
      assert storage_row.random_options == row.random_options
      assert Ecto.get_meta(storage_row, :state) == :loaded
    end
  end
end
