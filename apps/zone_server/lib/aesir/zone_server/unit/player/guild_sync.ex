defmodule Aesir.ZoneServer.Unit.Player.GuildSync do
  @moduledoc """
  Projects authoritative player state into the member snapshot shared by a
  guild, mirroring `Aesir.ZoneServer.Unit.Player.PartySync`.

  The projected `Guild.Member` carries the struct-default `position_index` (the
  session does not hold a guild position); `Guild.Manager.sync_member/3` preserves
  the stored member's `position_index` on presence updates, so only the presence
  fields projected here are applied.
  """

  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "Result of synchronizing a guild member snapshot."
  @type result :: :ok | {:error, term()}

  @doc """
  Synchronizes a player when their guild-visible projection changed.

  Passing `online: true | false` forces a complete presence snapshot for
  session attach and disconnect boundaries. A no-op for a player without a
  guild (`guild_id == 0`).
  """
  @spec sync(PlayerState.t(), PlayerState.t() | [{:online, boolean()}]) :: result()
  def sync(%PlayerState{}, %PlayerState{guild_id: 0}), do: :ok

  def sync(%PlayerState{} = previous, %PlayerState{} = current) do
    previous_member = member(previous, true)
    current_member = member(current, true)

    if previous.guild_id == current.guild_id and previous_member == current_member do
      :ok
    else
      synchronize(current.guild_id, current.character_id, current_member)
    end
  end

  def sync(%PlayerState{guild_id: 0}, online: online) when is_boolean(online), do: :ok

  def sync(%PlayerState{} = current, online: online) when is_boolean(online) do
    synchronize(current.guild_id, current.character_id, member(current, online))
  end

  defp member(%PlayerState{stats: stats} = state, online) do
    %Member{
      char_id: state.character_id,
      name: state.character_name,
      job_id: stats.progression.job_id,
      base_level: stats.progression.base_level,
      hp: stats.current_state.hp,
      max_hp: stats.derived_stats.max_hp,
      sp: stats.current_state.sp,
      max_sp: stats.derived_stats.max_sp,
      ap: stats.current_state.ap,
      max_ap: stats.derived_stats.max_ap,
      online: online,
      map_name: state.map_name
    }
  end

  defp synchronize(guild_id, char_id, member) do
    case Manager.sync_member(guild_id, char_id, member) do
      {:ok, _guild} -> :ok
      {:error, _reason} = error -> error
    end
  end
end
