defmodule Aesir.ZoneServer.Party.ViewTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.Net.PartyInfo
  alias Aesir.Net.PartyMember
  alias Aesir.Net.PartyMemberUpdate
  alias Aesir.ZoneServer.Party.View

  setup do
    leader =
      build(:party_member,
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
        map_name: "prontera"
      )

    wire_leader = %PartyMember{
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
      map: "prontera"
    }

    %{leader: leader, wire_leader: wire_leader}
  end

  test "party_info/1 preserves party fields and maps both online and offline members", %{
    leader: leader,
    wire_leader: wire_leader
  } do
    offline = build(:party_member, char_id: 84, name: "Bob", online: false)

    party =
      build(:party_state,
        party_id: 10,
        name: "Aesir",
        leader_char_id: leader.char_id,
        exp_share: true,
        item_pickup_share: true,
        members: [leader, offline]
      )

    assert %PartyInfo{
             party_id: 10,
             name: "Aesir",
             leader_char_id: 42,
             exp_share: true,
             item_pickup_share: true,
             members: [_, _] = members
           } = View.party_info(party)

    assert %{
             42 => ^wire_leader,
             84 => %PartyMember{char_id: 84, name: "Bob", online: false, map: ""}
           } =
             Map.new(members, &{&1.char_id, &1})
  end

  test "member_update/2 includes the party id and complete member", %{
    leader: leader,
    wire_leader: wire_leader
  } do
    assert %PartyMemberUpdate{party_id: 10, member: ^wire_leader} = View.member_update(10, leader)
  end
end
