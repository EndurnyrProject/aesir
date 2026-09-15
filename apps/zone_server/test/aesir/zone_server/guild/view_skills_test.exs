defmodule Aesir.ZoneServer.Guild.ViewSkillsTest do
  use ExUnit.Case, async: false

  alias Aesir.Net.GuildSkillEntry
  alias Aesir.ZoneServer.Guild.Progression.Data
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Guild.View

  @moduletag :tmp_dir

  setup context do
    on_exit(&Data.reload/0)
    {:ok, tmp_dir: dir} = Aesir.ZoneServer.DbTestSetup.configure_root(context, "guild")

    File.write!(Path.join(dir, "exp.yml"), "- level: 1\n  exp: 100\n")

    File.write!(Path.join(dir, "skill_tree.yml"), """
    - id: 10005
      max_level: 0
      prerequisites: []
    - id: 10000
      max_level: 10
      prerequisites: []
    - id: 10013
      max_level: 1
      prerequisites: []
    """)

    assert :ok = Data.reload()
  end

  test "guild_info/1 exposes every configured skill when none are learned" do
    guild = %State{guild_id: 10, name: "Aesir", master_char_id: 42}

    result = View.guild_info(guild)

    assert result.skills == [
             %GuildSkillEntry{skill_id: 10_000, level: 0, max_level: 10},
             %GuildSkillEntry{skill_id: 10_005, level: 0, max_level: 0},
             %GuildSkillEntry{skill_id: 10_013, level: 0, max_level: 1}
           ]
  end

  test "guild_info/1 combines configured and formerly learned skills without changing state" do
    learned_skills = %{99_999 => 3, 10_000 => 4}

    guild = %State{
      guild_id: 10,
      name: "Aesir",
      master_char_id: 42,
      learned_skills: learned_skills
    }

    result = View.guild_info(guild)

    assert result.skills == [
             %GuildSkillEntry{skill_id: 10_000, level: 4, max_level: 10},
             %GuildSkillEntry{skill_id: 10_005, level: 0, max_level: 0},
             %GuildSkillEntry{skill_id: 10_013, level: 0, max_level: 1},
             %GuildSkillEntry{skill_id: 99_999, level: 3, max_level: 3}
           ]

    assert guild.learned_skills == learned_skills
  end
end
