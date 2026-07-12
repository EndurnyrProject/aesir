Code.require_file(
  Path.expand(
    "../../../../priv/repo/migrations/20260712120000_add_trait_stats_to_characters.exs",
    __DIR__
  )
)

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

  describe "migration backfill" do
    alias Aesir.Repo.Migrations.AddTraitStatsToCharacters

    defp run_backfill do
      Repo.query!(AddTraitStatsToCharacters.table_backfill_sql())
      Repo.query!(AddTraitStatsToCharacters.flat_backfill_sql())
    end

    test "grants trait_table[level] + 7 to a trait-job character at base level 210" do
      account = account!()

      {:ok, character} =
        %Character{}
        |> Character.changeset(valid_attrs(account, %{class: 4252, base_level: 210}))
        |> Repo.insert()

      run_backfill()

      assert %Character{trait_point: 45} = Repo.get!(Character, character.id)
    end

    test "grants the flat +7 to a trait-job character below base level 201" do
      account = account!()

      {:ok, character} =
        %Character{}
        |> Character.changeset(valid_attrs(account, %{class: 4252, base_level: 150}))
        |> Repo.insert()

      run_backfill()

      assert %Character{trait_point: 7} = Repo.get!(Character, character.id)
    end

    test "leaves a non-trait character's trait_point at zero" do
      account = account!()

      {:ok, character} =
        %Character{}
        |> Character.changeset(valid_attrs(account, %{class: 0, base_level: 210}))
        |> Repo.insert()

      run_backfill()

      assert %Character{trait_point: 0} = Repo.get!(Character, character.id)
    end
  end
end
