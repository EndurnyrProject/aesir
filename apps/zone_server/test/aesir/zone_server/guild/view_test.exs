defmodule Aesir.ZoneServer.Guild.ViewTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Guild.View

  test "member/1 maps every guild member field" do
    member = %Member{
      char_id: 42,
      name: "Alice",
      job_id: 4054,
      base_level: 175,
      position_index: 3,
      hp: 12_345,
      max_hp: 23_456,
      sp: 1_234,
      max_sp: 2_345,
      ap: 87,
      max_ap: 200,
      online: true,
      map_name: nil
    }

    result = View.member(member)

    assert result.char_id == 42
    assert result.name == "Alice"
    assert result.job_id == 4054
    assert result.base_level == 175
    assert result.position_index == 3
    assert result.hp == 12_345
    assert result.max_hp == 23_456
    assert result.sp == 1_234
    assert result.max_sp == 2_345
    assert result.ap == 87
    assert result.max_ap == 200
    assert result.online == true
    assert result.map == ""
  end

  test "member/1 defaults map to empty string when map_name is set" do
    member = %Member{
      char_id: 84,
      name: "Bob",
      base_level: 99,
      position_index: 19,
      online: false,
      map_name: "prontera"
    }

    result = View.member(member)

    assert result.map == "prontera"
  end

  test "position/1 maps every position field" do
    position = %Position{
      index: 0,
      name: "GuildMaster",
      can_invite: true,
      can_expel: true,
      can_storage: false,
      tax: 0
    }

    result = View.position(position)

    assert result.index == 0
    assert result.name == "GuildMaster"
    assert result.can_invite == true
    assert result.can_expel == true
    assert result.can_storage == false
    assert result.tax == 0
  end

  test "guild_info/1 preserves guild fields and maps members and positions" do
    leader = %Member{
      char_id: 42,
      name: "Alice",
      job_id: 4054,
      base_level: 175,
      position_index: 0,
      hp: 12_345,
      max_hp: 23_456,
      sp: 1_234,
      max_sp: 2_345,
      ap: 87,
      max_ap: 200,
      online: true,
      map_name: "prontera"
    }

    member = %Member{
      char_id: 84,
      name: "Bob",
      job_id: 7,
      base_level: 99,
      position_index: 19,
      hp: 500,
      max_hp: 1_000,
      sp: 200,
      max_sp: 400,
      ap: 0,
      max_ap: 0,
      online: false,
      map_name: nil
    }

    positions = Position.defaults() |> Enum.map(&{&1.index, &1}) |> Map.new()

    guild = %State{
      guild_id: 10,
      name: "Aesir",
      master_char_id: 42,
      emblem_id: 3,
      notice: %{subject: "Welcome", body: "Read the rules"},
      positions: positions,
      members: %{leader.char_id => leader, member.char_id => member}
    }

    result = View.guild_info(guild)

    assert result.guild_id == 10
    assert result.name == "Aesir"
    assert result.master_char_id == 42
    assert result.emblem_id == 3
    assert result.notice_subject == "Welcome"
    assert result.notice_body == "Read the rules"
    assert length(result.members) == 2
    assert length(result.positions) == 20

    mapped_leader = Enum.find(result.members, &(&1.char_id == 42))
    assert mapped_leader.position_index == 0
    assert mapped_leader.map == "prontera"

    mapped_member = Enum.find(result.members, &(&1.char_id == 84))
    assert mapped_member.position_index == 19
    assert mapped_member.map == ""

    assert result.positions |> Enum.map(& &1.index) == Enum.to_list(0..19)
    master_position = Enum.find(result.positions, &(&1.index == 0))
    assert master_position.name == "GuildMaster"
    assert master_position.can_invite == true
    assert master_position.can_expel == true
  end

  test "member_update/2 includes the guild id and complete member" do
    member = %Member{
      char_id: 42,
      name: "Alice",
      job_id: 4054,
      base_level: 175,
      position_index: 0,
      hp: 12_345,
      max_hp: 23_456,
      sp: 1_234,
      max_sp: 2_345,
      ap: 87,
      max_ap: 200,
      online: true,
      map_name: "prontera"
    }

    result = View.member_update(10, member)

    assert result.guild_id == 10
    assert result.member.char_id == 42
    assert result.member.position_index == 0
    assert result.member.map == "prontera"
  end
end
