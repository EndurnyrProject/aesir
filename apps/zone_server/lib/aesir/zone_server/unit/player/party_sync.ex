defmodule Aesir.ZoneServer.Unit.Player.PartySync do
  @moduledoc """
  Projects authoritative player state into the member snapshot shared by a party.
  """

  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "Result of synchronizing a party member snapshot."
  @type result :: :ok | {:error, term()}

  @doc """
  Synchronizes a player when their party-visible projection changed.

  Passing `online: true | false` forces a complete presence snapshot for
  session attach and disconnect boundaries.
  """
  @spec sync(PlayerState.t(), PlayerState.t() | [{:online, boolean()}]) :: result()
  def sync(%PlayerState{} = previous, %PlayerState{} = current) do
    previous_member = member(previous, true)
    current_member = member(current, true)

    if current.party_id == 0 or
         (previous.party_id == current.party_id and previous_member == current_member) do
      :ok
    else
      synchronize(current.party_id, current.character_id, current_member)
    end
  end

  def sync(%PlayerState{party_id: 0}, online: online) when is_boolean(online), do: :ok

  def sync(%PlayerState{} = current, online: online) when is_boolean(online) do
    synchronize(current.party_id, current.character_id, member(current, online))
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

  defp synchronize(party_id, char_id, member) do
    case Manager.sync_member(party_id, char_id, member) do
      {:ok, _party} -> :ok
      {:error, _reason} = error -> error
    end
  end
end
