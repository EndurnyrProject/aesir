defmodule Aesir.Commons.Models.AccountTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account

  defp valid_attrs(extra \\ %{}) do
    Map.merge(
      %{
        userid: "tester",
        user_pass: "secret",
        email: "tester@example.com"
      },
      extra
    )
  end

  describe "changeset/2" do
    test "defaults gm_level to 0 on a freshly inserted account" do
      assert {:ok, account} =
               %Account{}
               |> Account.changeset(valid_attrs())
               |> Repo.insert()

      assert account.gm_level == 0
    end

    test "casts and persists a gm_level value" do
      assert {:ok, account} =
               %Account{}
               |> Account.changeset(valid_attrs(%{gm_level: 60}))
               |> Repo.insert()

      assert account.gm_level == 60
      assert Repo.get!(Account, account.id).gm_level == 60
    end

    test "does not require gm_level" do
      changeset = Account.changeset(%Account{}, valid_attrs())
      assert changeset.valid?
    end
  end
end
