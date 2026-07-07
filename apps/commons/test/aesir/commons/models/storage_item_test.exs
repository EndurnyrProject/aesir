defmodule Aesir.Commons.Models.StorageItemTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.StorageItem

  defp account! do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "storagetester",
        user_pass: "secret",
        email: "storagetester@example.com"
      })
      |> Repo.insert()

    account
  end

  describe "changeset/2" do
    test "declares account_id, nameid and amount as required" do
      changeset = StorageItem.changeset(%StorageItem{}, %{})

      refute changeset.valid?
      assert Enum.sort(changeset.required) == [:account_id, :amount, :nameid]
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a non-positive amount" do
      changeset =
        StorageItem.changeset(%StorageItem{amount: 5}, %{account_id: 1, nameid: 501, amount: 0})

      refute changeset.valid?
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "accepts a valid item" do
      changeset = StorageItem.changeset(%StorageItem{}, %{account_id: 1, nameid: 501, amount: 3})

      assert changeset.valid?
    end
  end

  describe "Account storage association" do
    test "defines the :storage_items association" do
      assert %Ecto.Association.Has{related: StorageItem} =
               Account.__schema__(:association, :storage_items)
    end

    test "round-trips a storage item through the association" do
      account = account!()

      {:ok, _item} =
        %StorageItem{}
        |> StorageItem.changeset(%{account_id: account.id, nameid: 501, amount: 5})
        |> Repo.insert()

      account = Repo.preload(account, :storage_items)

      assert [%StorageItem{nameid: 501, amount: 5}] = account.storage_items
    end
  end
end
