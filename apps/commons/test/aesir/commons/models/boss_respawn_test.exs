defmodule Aesir.Commons.Models.BossRespawnTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.BossRespawn

  defp valid_attrs(extra \\ %{}) do
    Map.merge(
      %{
        map_name: "gld_dun03",
        mob_id: 1039,
        respawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      extra
    )
  end

  describe "changeset/2" do
    test "accepts valid attrs" do
      changeset = BossRespawn.changeset(%BossRespawn{}, valid_attrs())
      assert changeset.valid?
    end

    test "requires map_name, mob_id and respawn_at" do
      changeset = BossRespawn.changeset(%BossRespawn{}, %{})

      refute changeset.valid?

      assert %{
               map_name: ["can't be blank"],
               mob_id: ["can't be blank"],
               respawn_at: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "inserts and reads back through Aesir.Repo" do
      assert {:ok, row} =
               %BossRespawn{}
               |> BossRespawn.changeset(valid_attrs())
               |> Aesir.Repo.insert()

      assert row.map_name == "gld_dun03"
      assert row.mob_id == 1039
      assert row.inserted_at != nil
    end
  end
end
