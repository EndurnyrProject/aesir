defmodule Aesir.Commons.Models.CharacterTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character

  defp account! do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "vartester",
        user_pass: "secret",
        email: "vartester@example.com"
      })
      |> Repo.insert()

    account
  end

  defp valid_attrs(account, extra \\ %{}) do
    Map.merge(
      %{
        account_id: account.id,
        char_num: 0,
        name: "VarHero",
        class: 0
      },
      extra
    )
  end

  describe "changeset/2 vars" do
    test "defaults vars to an empty map on a freshly inserted character" do
      account = account!()

      assert {:ok, character} =
               %Character{}
               |> Character.changeset(valid_attrs(account))
               |> Repo.insert()

      assert %Character{vars: %{}} = character
    end

    test "casts and round-trips a vars map through the repo" do
      account = account!()

      assert {:ok, character} =
               %Character{}
               |> Character.changeset(valid_attrs(account, %{vars: %{"sphmask_q" => 1}}))
               |> Repo.insert()

      assert %Character{vars: %{"sphmask_q" => 1}} = Repo.get!(Character, character.id)
    end
  end
end
