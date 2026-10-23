defmodule Aesir.Commons.Models.ItemOptionsTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem

  defp character! do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "optiontester",
        user_pass: "secret",
        email: "optiontester@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{account_id: account.id, char_num: 0, name: "OptHero", class: 0})
      |> Repo.insert()

    character
  end

  test "keeps option order and repeated ids through a reload" do
    character = character!()

    options = [
      %{id: 3, value: 5, param: 0},
      %{id: 1, value: -2, param: 7},
      %{id: 3, value: 1, param: 0}
    ]

    {:ok, item} =
      %InventoryItem{}
      |> InventoryItem.changeset(%{
        char_id: character.id,
        nameid: 1201,
        amount: 1,
        random_options: options
      })
      |> Repo.insert()

    assert Repo.get!(InventoryItem, item.id).random_options == options
  end

  test "keeps an empty slot before a filled one and drops trailing empty slots" do
    character = character!()
    empty = %{id: 0, value: 0, param: 0}

    {:ok, item} =
      %InventoryItem{}
      |> InventoryItem.changeset(%{
        char_id: character.id,
        nameid: 1201,
        amount: 1,
        random_options: [empty, %{id: 4, value: 2, param: 0}, empty]
      })
      |> Repo.insert()

    assert Repo.get!(InventoryItem, item.id).random_options == [
             empty,
             %{id: 4, value: 2, param: 0}
           ]
  end

  test "a row without options loads as an empty list" do
    character = character!()

    {:ok, item} =
      %InventoryItem{}
      |> InventoryItem.changeset(%{char_id: character.id, nameid: 1201, amount: 1})
      |> Repo.insert()

    assert Repo.get!(InventoryItem, item.id).random_options == []
  end
end
