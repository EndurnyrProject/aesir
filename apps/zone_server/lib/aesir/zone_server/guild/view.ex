defmodule Aesir.ZoneServer.Guild.View do
  @moduledoc """
  Converts guild domain snapshots to their Protobuf messages.
  """

  alias Aesir.Net.GuildInfo
  alias Aesir.Net.GuildMember
  alias Aesir.Net.GuildMemberUpdate
  alias Aesir.Net.GuildPosition
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State

  @doc "Converts one complete guild member snapshot to its Protobuf message."
  @spec member(Member.t()) :: GuildMember.t()
  def member(%Member{} = member) do
    %GuildMember{
      char_id: member.char_id,
      name: member.name,
      job_id: member.job_id,
      base_level: member.base_level,
      online: member.online,
      map: member.map_name || "",
      position_index: member.position_index,
      hp: member.hp,
      max_hp: member.max_hp,
      sp: member.sp,
      max_sp: member.max_sp,
      ap: member.ap,
      max_ap: member.max_ap
    }
  end

  @doc "Converts one guild position slot to its Protobuf message."
  @spec position(Position.t()) :: GuildPosition.t()
  def position(%Position{} = position) do
    %GuildPosition{
      index: position.index,
      name: position.name,
      can_invite: position.can_invite,
      can_expel: position.can_expel,
      can_storage: position.can_storage,
      tax: position.tax
    }
  end

  @doc "Converts a complete guild state to its Protobuf roster message."
  @spec guild_info(State.t()) :: GuildInfo.t()
  def guild_info(%State{} = guild) do
    %GuildInfo{
      guild_id: guild.guild_id,
      name: guild.name,
      master_char_id: guild.master_char_id,
      emblem_id: guild.emblem_id,
      notice_subject: guild.notice.subject,
      notice_body: guild.notice.body,
      positions:
        guild.positions
        |> Map.values()
        |> Enum.sort_by(& &1.index)
        |> Enum.map(&position/1),
      members: guild.members |> Map.values() |> Enum.map(&member/1)
    }
  end

  @doc "Builds a complete single-member update for a guild."
  @spec member_update(non_neg_integer(), Member.t()) :: GuildMemberUpdate.t()
  def member_update(guild_id, %Member{} = guild_member) do
    %GuildMemberUpdate{guild_id: guild_id, member: member(guild_member)}
  end
end
