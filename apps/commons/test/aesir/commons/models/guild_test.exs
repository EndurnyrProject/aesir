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

  describe "progression fields" do
    test "insert defaults to level 1 with no exp, points, or skills" do
      assert {:ok, guild} =
               %Guild{}
               |> Guild.changeset(valid_attrs())
               |> Repo.insert()

      assert guild.level == 1
      assert guild.exp == 0
      assert guild.skill_points == 0
      assert guild.learned_skills == %{}
    end

    test "persists exp beyond the int4 range" do
      assert {:ok, guild} =
               %Guild{}
               |> Guild.changeset(
                 valid_attrs(%{
                   level: 50,
                   exp: 3_000_000_000,
                   skill_points: 3,
                   learned_skills: %{"10004" => 3}
                 })
               )
               |> Repo.insert()

      reloaded = Repo.get!(Guild, guild.id)
      assert reloaded.exp == 3_000_000_000
      assert reloaded.learned_skills == %{"10004" => 3}
    end

    test "rejects explicit nil progression values" do
      assert %{level: _} = errors_on(Guild.changeset(%Guild{}, valid_attrs(%{level: nil})))
      assert %{exp: _} = errors_on(Guild.changeset(%Guild{}, valid_attrs(%{exp: nil})))
    end

    test "rejects out-of-range level" do
      assert %{level: _} = errors_on(Guild.changeset(%Guild{}, valid_attrs(%{level: 0})))
      assert %{level: _} = errors_on(Guild.changeset(%Guild{}, valid_attrs(%{level: 51})))
    end

    test "rejects negative exp and skill points" do
      assert %{exp: _} = errors_on(Guild.changeset(%Guild{}, valid_attrs(%{exp: -1})))

      assert %{skill_points: _} =
               errors_on(Guild.changeset(%Guild{}, valid_attrs(%{skill_points: -1})))
    end
  end
end
