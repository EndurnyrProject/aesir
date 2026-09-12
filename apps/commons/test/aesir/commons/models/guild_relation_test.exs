defmodule Aesir.Commons.Models.GuildRelationTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Guild
  alias Aesir.Commons.Models.GuildRelation

  defp guild!(name) do
    {:ok, guild} =
      %Guild{}
      |> Guild.changeset(%{name: name, master_char_id: 1})
      |> Repo.insert()

    guild
  end

  defp valid_attrs(guild, other_guild, extra \\ %{}) do
    Map.merge(
      %{
        guild_id: guild.id,
        other_guild_id: other_guild.id,
        kind: "ally",
        other_name: other_guild.name
      },
      extra
    )
  end

  describe "changeset/2" do
    test "accepts a valid ally relation" do
      guild = guild!("Valhalla")
      other = guild!("Asgard")

      changeset = GuildRelation.changeset(%GuildRelation{}, valid_attrs(guild, other))

      assert changeset.valid?
    end

    test "requires guild_id, other_guild_id, kind, and other_name" do
      changeset = GuildRelation.changeset(%GuildRelation{}, %{})

      refute changeset.valid?

      assert %{
               guild_id: ["can't be blank"],
               other_guild_id: ["can't be blank"],
               kind: ["can't be blank"],
               other_name: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "rejects a kind outside ally/antagonist" do
      guild = guild!("Valhalla")
      other = guild!("Asgard")

      changeset =
        GuildRelation.changeset(%GuildRelation{}, valid_attrs(guild, other, %{kind: "friend"}))

      refute changeset.valid?
      assert %{kind: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "persistence" do
    test "enforces the (guild_id, other_guild_id) unique constraint" do
      guild = guild!("Valhalla")
      other = guild!("Asgard")

      {:ok, _relation} =
        %GuildRelation{}
        |> GuildRelation.changeset(valid_attrs(guild, other))
        |> Repo.insert()

      {:error, changeset} =
        %GuildRelation{}
        |> GuildRelation.changeset(valid_attrs(guild, other, %{kind: "antagonist"}))
        |> Repo.insert()

      assert %{guild_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "deletes relation rows when the owning guild is deleted" do
      guild = guild!("Valhalla")
      other = guild!("Asgard")

      {:ok, relation} =
        %GuildRelation{}
        |> GuildRelation.changeset(valid_attrs(guild, other))
        |> Repo.insert()

      Repo.delete!(guild)

      assert Repo.get(GuildRelation, relation.id) == nil
    end

    test "deletes relation rows when the other guild is deleted" do
      guild = guild!("Valhalla")
      other = guild!("Asgard")

      {:ok, relation} =
        %GuildRelation{}
        |> GuildRelation.changeset(valid_attrs(guild, other))
        |> Repo.insert()

      Repo.delete!(other)

      assert Repo.get(GuildRelation, relation.id) == nil
    end
  end
end
