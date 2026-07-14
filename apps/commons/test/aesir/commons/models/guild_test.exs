defmodule Aesir.Commons.Models.GuildTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Guild

  defp valid_attrs(extra \\ %{}) do
    Map.merge(
      %{
        name: "Valhalla",
        master_char_id: 1
      },
      extra
    )
  end

  describe "changeset/2" do
    test "accepts valid attrs" do
      changeset = Guild.changeset(%Guild{}, valid_attrs())
      assert changeset.valid?
    end

    test "requires name and master_char_id" do
      changeset = Guild.changeset(%Guild{}, %{})

      refute changeset.valid?

      assert %{name: ["can't be blank"], master_char_id: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "rejects a blank name after trimming" do
      changeset = Guild.changeset(%Guild{}, valid_attrs(%{name: "   "}))

      refute changeset.valid?
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "rejects a duplicate name as a changeset error, not a raised error" do
      assert {:ok, _guild} =
               %Guild{}
               |> Guild.changeset(valid_attrs())
               |> Repo.insert()

      assert {:error, changeset} =
               %Guild{}
               |> Guild.changeset(valid_attrs(%{master_char_id: 2}))
               |> Repo.insert()

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "defaults emblem_id to 0 on insert" do
      assert {:ok, guild} =
               %Guild{}
               |> Guild.changeset(valid_attrs())
               |> Repo.insert()

      assert guild.emblem_id == 0
    end
  end

  describe "new/1" do
    test "builds an insertable changeset from attrs" do
      changeset = Guild.new(valid_attrs())
      assert changeset.valid?
    end
  end
end
