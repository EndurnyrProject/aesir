defmodule Aesir.Commons.Models.CartItemTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character

  defp account! do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "carttester",
        user_pass: "secret",
        email: "carttester@example.com"
      })
      |> Repo.insert()

    account
  end

  defp character!(account) do
    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "CartHero",
        class: 0
      })
      |> Repo.insert()

    character
  end

  describe "changeset/2" do
    test "declares char_id, nameid and amount as required" do
      changeset = CartItem.changeset(%CartItem{}, %{})

      refute changeset.valid?
      assert Enum.sort(changeset.required) == [:amount, :char_id, :nameid]
      assert %{char_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a non-positive amount" do
      changeset = CartItem.changeset(%CartItem{amount: 5}, %{char_id: 1, nameid: 501, amount: 0})

      refute changeset.valid?
      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "accepts a valid item" do
      changeset = CartItem.changeset(%CartItem{}, %{char_id: 1, nameid: 501, amount: 3})

      assert changeset.valid?
    end
  end

  describe "Character cart association" do
    test "exposes :cart defaulting to 0" do
      assert %Character{cart: 0} = %Character{}
    end

    test "defines the :cart_items association" do
      assert %Ecto.Association.Has{related: CartItem} =
               Character.__schema__(:association, :cart_items)
    end

    test "round-trips a cart item through the association" do
      account = account!()
      character = character!(account)

      {:ok, _item} =
        %CartItem{}
        |> CartItem.changeset(%{char_id: character.id, nameid: 501, amount: 5})
        |> Repo.insert()

      character = Repo.preload(character, :cart_items)

      assert [%CartItem{nameid: 501, amount: 5}] = character.cart_items
    end
  end
end
