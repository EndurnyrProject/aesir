defmodule Aesir.ZoneServer.Party.View do
  @moduledoc """
  Converts party domain snapshots to their Protobuf messages.
  """

  alias Aesir.Net.PartyInfo
  alias Aesir.Net.PartyMember
  alias Aesir.Net.PartyMemberUpdate
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State

  @doc "Converts one complete party member snapshot to its Protobuf message."
  @spec member(Member.t()) :: PartyMember.t()
  def member(%Member{} = member) do
    %PartyMember{
      char_id: member.char_id,
      name: member.name,
      job_id: member.job_id,
      base_level: member.base_level,
      hp: member.hp,
      max_hp: member.max_hp,
      sp: member.sp,
      max_sp: member.max_sp,
      ap: member.ap,
      max_ap: member.max_ap,
      online: member.online,
      map: member.map_name || ""
    }
  end

  @doc "Converts a complete party state to its Protobuf roster message."
  @spec party_info(State.t()) :: PartyInfo.t()
  def party_info(%State{} = party) do
    %PartyInfo{
      party_id: party.party_id,
      name: party.name,
      leader_char_id: party.leader_char_id,
      exp_share: party.exp_share,
      members: party.members |> Map.values() |> Enum.map(&member/1)
    }
  end

  @doc "Builds a complete single-member update for a party."
  @spec member_update(non_neg_integer(), Member.t()) :: PartyMemberUpdate.t()
  def member_update(party_id, %Member{} = party_member) do
    %PartyMemberUpdate{party_id: party_id, member: member(party_member)}
  end
end
