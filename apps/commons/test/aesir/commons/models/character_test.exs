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

  describe "changeset/2 pvp counters" do
    test "defaults the pvp counters to zero at the database layer" do
      account = account!()
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      assert {1, nil} =
               Repo.insert_all(Character, [
                 %{
                   account_id: account.id,
                   char_num: 0,
                   name: "PvpDefaultHero",
                   class: 0,
                   inserted_at: now,
                   updated_at: now
                 }
               ])

      assert %Character{pvp_point: 0, pvp_won: 0, pvp_lost: 0} =
               Repo.get_by!(Character, name: "PvpDefaultHero")
    end

    test "casts and round-trips a signed pvp_point through the repo" do
      account = account!()

      assert {:ok, character} =
               %Character{}
               |> Character.changeset(
                 valid_attrs(account, %{pvp_point: -5, pvp_won: 0, pvp_lost: 1})
               )
               |> Repo.insert()

      assert %Character{pvp_point: -5, pvp_won: 0, pvp_lost: 1} =
               Repo.get!(Character, character.id)
    end
  end

  describe "changeset/2 trait stats" do
    test "defaults the ten trait columns to zero on a freshly inserted character" do
      account = account!()

      assert {:ok, character} =
               %Character{}
               |> Character.changeset(valid_attrs(account))
               |> Repo.insert()

      assert %Character{
               pow: 0,
               sta: 0,
               wis: 0,
               spl: 0,
               con: 0,
               crt: 0,
               trait_point: 0,
               ap: 0,
               max_ap: 0
             } = character
    end

    test "casts and round-trips pow/trait_point/max_ap through the repo" do
      account = account!()

      assert {:ok, character} =
               %Character{}
               |> Character.changeset(
                 valid_attrs(account, %{pow: 30, trait_point: 12, max_ap: 50})
               )
               |> Repo.insert()

      assert %Character{pow: 30, trait_point: 12, max_ap: 50} =
               Repo.get!(Character, character.id)
    end
  end
end
