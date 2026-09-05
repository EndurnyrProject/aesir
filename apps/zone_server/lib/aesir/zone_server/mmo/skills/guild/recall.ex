defmodule Aesir.ZoneServer.Mmo.Skills.Guild.Recall do
  @moduledoc """
  Shared recall logic for the guild Urgent Call skills.

  Warps online guild members (the caster excluded, matching the reference) to
  the ring of cells around the master's position, preferring walkable cells
  and falling back to the master's own cell. Offline members and despawned
  sessions are skipped; every warp is an async cast to the member's own
  session, so a member dying or logging out mid-recall is a safe no-op.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # The reference summon ring: eight surrounding cells plus the center.
  @ring [{-1, 0}, {1, 0}, {0, 1}, {0, -1}, {-1, 1}, {1, -1}, {-1, -1}, {1, 1}, {0, 0}]

  @doc "Validates that the caster is the guild master and the destination permits recall."
  @spec validate_master(PlayerState.t()) :: :ok | {:error, :not_guild_master | :not_gvg_ground}
  def validate_master(%PlayerState{guild_id: guild_id}) when guild_id in [nil, 0],
    do: {:error, :not_guild_master}

  def validate_master(%PlayerState{guild_id: guild_id, character_id: char_id, map_name: map_name}) do
    case GuildManager.get(guild_id) do
      {:ok, %{master_char_id: ^char_id}} ->
        if Config.guild_skills_gvg_only() and not Rules.ground?(map_name),
          do: {:error, :not_gvg_ground},
          else: :ok

      _not_master_or_missing ->
        {:error, :not_guild_master}
    end
  end

  @doc """
  Warps up to `max_calls` online guild members (`:all` = no cap) next to the
  caster.
  """
  @spec summon_members(PlayerState.t(), pos_integer() | :all) :: :ok
  def summon_members(%PlayerState{} = caster, max_calls) do
    with :ok <- validate_master(caster),
         {:ok, guild} <- GuildManager.get(caster.guild_id),
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
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{map_name: map_name}, pid}} ->
        if not MapFlags.get(map_name, :nowarp) or Rules.ground?(map_name), do: [pid], else: []

      {:error, :not_found} ->
        []
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
