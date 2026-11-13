defmodule Aesir.Commons.Models.GuildActivityLogTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Guild
  alias Aesir.Commons.Models.GuildActivityLog

  defp guild!(name) do
    {:ok, guild} =
      %Guild{}
      |> Guild.changeset(%{name: name, master_char_id: 1})
      |> Repo.insert()

    guild
  end

  describe "changeset/2" do
    test "requires a guild and a kind" do
      changeset = GuildActivityLog.changeset(%GuildActivityLog{}, %{})

      refute changeset.valid?
      assert %{guild_id: ["can't be blank"], kind: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a kind the log does not define" do
      changeset = GuildActivityLog.changeset(%GuildActivityLog{}, %{guild_id: 1, kind: "renamed"})

      assert %{kind: ["is invalid"]} = errors_on(changeset)
    end

    test "persists an entry with empty defaults for the fields its kind does not fill" do
      guild = guild!("Valhalla")

      assert {:ok, log} =
               %GuildActivityLog{}
               |> GuildActivityLog.changeset(%{
                 guild_id: guild.id,
                 kind: "skill_learned",
                 actor: "Brynhild",
                 subject: "",
                 skill_id: 10_004,
                 level: 2
               })
               |> Repo.insert()

      assert %GuildActivityLog{
               kind: "skill_learned",
               subject: "",
               actor: "Brynhild",
               detail: "",
               skill_id: 10_004,
               level: 2,
               inserted_at: %DateTime{}
             } = Repo.get!(GuildActivityLog, log.id)
    end

    test "reports an unknown guild as a changeset error instead of raising" do
      assert {:error, changeset} =
               %GuildActivityLog{}
               |> GuildActivityLog.changeset(%{guild_id: 999_999, kind: "created"})
               |> Repo.insert()

      assert %{guild_id: ["does not exist"]} = errors_on(changeset)
    end
  end

  test "a guild's entries are deleted with the guild" do
    guild = guild!("Midgard")

    {:ok, _log} =
      %GuildActivityLog{}
      |> GuildActivityLog.changeset(%{guild_id: guild.id, kind: "created", actor: "Founder"})
      |> Repo.insert()

    {:ok, _guild} = Repo.delete(guild)

    assert Repo.all(GuildActivityLog) == []
  end
end
