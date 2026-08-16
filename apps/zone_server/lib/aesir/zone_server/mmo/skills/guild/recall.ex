defmodule Aesir.ZoneServer.Mmo.Skills.Guild.Recall do
  @moduledoc """
  Shared recall logic for the guild Urgent Call skills.

  Warps online guild members (the caster excluded, matching the reference) to
  the ring of cells around the master's position, preferring walkable cells
  and falling back to the master's own cell. Offline members and despawned
  sessions are skipped; every warp is an async cast to the member's own
  session, so a member dying or logging out mid-recall is a safe no-op.
  """

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # The reference summon ring: eight surrounding cells plus the center.
  @ring [{-1, 0}, {1, 0}, {0, 1}, {0, -1}, {-1, 1}, {1, -1}, {-1, -1}, {1, 1}, {0, 0}]

  defdelegate validate_master(caster), to: Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea

  @doc """
  Warps up to `max_calls` online guild members (`:all` = no cap) next to the
  caster.
  """
  @spec summon_members(PlayerState.t(), pos_integer() | :all) :: :ok
  def summon_members(%PlayerState{} = caster, max_calls) do
    with {:ok, guild} <- GuildManager.get(caster.guild_id),
         {:ok, {x, y, map_name}} <-
           SpatialIndex.get_unit_position(:player, caster.character_id) do
      guild.members
      |> Map.keys()
      |> Enum.reject(&(&1 == caster.character_id))
      |> Enum.flat_map(&resolve_session/1)
      |> cap(max_calls)
      |> Enum.with_index()
      |> Enum.each(fn {pid, index} ->
        {dx, dy} = ring_cell(map_name, x, y, index)
        PlayerSession.warp(pid, map_name, x + dx, y + dy)
      end)
    else
      _missing -> :ok
    end

    :ok
  end

  defp resolve_session(char_id) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} -> [pid]
      {:error, :not_found} -> []
    end
  end

  defp cap(members, :all), do: members
  defp cap(members, max_calls), do: Enum.take(members, max_calls)

  defp ring_cell(map_name, x, y, index) do
    {dx, dy} = Enum.at(@ring, rem(index, length(@ring)))

    if MapCache.walkable?(map_name, x + dx, y + dy) do
      {dx, dy}
    else
      {0, 0}
    end
  end
end
