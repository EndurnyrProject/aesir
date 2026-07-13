defmodule Aesir.ZoneServer.Party.ViewTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State
  alias Aesir.ZoneServer.Party.View

  test "member/1 maps every party member field" do
    member = %Member{
      char_id: 42,
      name: "Alice",
      job_id: 4054,
      base_level: 175,
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
    assert result.hp == 12_345
    assert result.max_hp == 23_456
    assert result.sp == 1_234
    assert result.max_sp == 2_345
    assert result.ap == 87
    assert result.max_ap == 200
    assert result.online == true
    assert result.map == ""
  end

  test "party_info/1 preserves party fields and maps every member" do
    leader = %Member{
      char_id: 42,
      name: "Alice",
      job_id: 4054,
      base_level: 175,
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
      hp: 500,
      max_hp: 1_000,
      sp: 200,
      max_sp: 400,
      ap: 0,
      max_ap: 0,
      online: false,
      map_name: nil
    }

    party = %State{
      party_id: 10,
      name: "Aesir",
      leader_char_id: leader.char_id,
      exp_share: true,
      members: %{leader.char_id => leader, member.char_id => member}
    }

    result = View.party_info(party)

    assert result.party_id == 10
    assert result.name == "Aesir"
    assert result.leader_char_id == 42
    assert result.exp_share == true
    assert length(result.members) == 2

    mapped_leader = Enum.find(result.members, &(&1.char_id == 42))
    assert mapped_leader.char_id == 42
    assert mapped_leader.name == "Alice"
    assert mapped_leader.job_id == 4054
    assert mapped_leader.base_level == 175
    assert mapped_leader.hp == 12_345
    assert mapped_leader.max_hp == 23_456
    assert mapped_leader.sp == 1_234
    assert mapped_leader.max_sp == 2_345
    assert mapped_leader.ap == 87
    assert mapped_leader.max_ap == 200
    assert mapped_leader.online == true
    assert mapped_leader.map == "prontera"

    mapped_member = Enum.find(result.members, &(&1.char_id == 84))
    assert mapped_member.char_id == 84
    assert mapped_member.name == "Bob"
    assert mapped_member.job_id == 7
    assert mapped_member.base_level == 99
    assert mapped_member.hp == 500
    assert mapped_member.max_hp == 1_000
    assert mapped_member.sp == 200
    assert mapped_member.max_sp == 400
    assert mapped_member.ap == 0
    assert mapped_member.max_ap == 0
    assert mapped_member.online == false
    assert mapped_member.map == ""
  end

  test "member_update/2 includes the party id and complete member" do
    member = %Member{
      char_id: 42,
      name: "Alice",
      job_id: 4054,
      base_level: 175,
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

    assert result.party_id == 10
    assert result.member.char_id == 42
    assert result.member.name == "Alice"
    assert result.member.job_id == 4054
    assert result.member.base_level == 175
    assert result.member.hp == 12_345
    assert result.member.max_hp == 23_456
    assert result.member.sp == 1_234
    assert result.member.max_sp == 2_345
    assert result.member.ap == 87
    assert result.member.max_ap == 200
    assert result.member.online == true
    assert result.member.map == "prontera"
  end
end
