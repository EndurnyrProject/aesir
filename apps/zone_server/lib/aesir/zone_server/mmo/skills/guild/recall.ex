defmodule Aesir.ZoneServer.Mmo.Skills.Guild.Recall do
  @moduledoc """
  Shared recall logic for the guild Urgent Call skills.

  The GvG ground check runs before the cast starts (the caster's map
  restrictions); `validate_master/1` is the cast-begin check, which drops the
  cast silently when the caster is not his guild's master. The effect needs
  only the caster's guild.

  `summon_members/2` walks the guild's member list in slot order and warps each
  online, living member other than the caster whose map allows warping out
  (no `nowarp`, or GvG ground) next to the caster, until `max_calls` members
  were warped. A member's destination is the ring cell of its slot (slot
  modulo 9, so skipped and empty slots still advance the ring), or the
  caster's own cell when that ring cell is not walkable. Every warp is an async
  cast to the member's own session.
  """

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildCooldown
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @ring [{-1, 0}, {1, 0}, {0, 1}, {0, -1}, {-1, 1}, {1, -1}, {-1, -1}, {1, 1}, {0, 0}]

  @doc """
  Drops the cast silently (`:guild_skill_unavailable`) when the caster is not
  his guild's master.
  """
  @spec validate_master(PlayerState.t()) :: :ok | {:error, :guild_skill_unavailable}
  def validate_master(%PlayerState{guild_id: guild_id}) when guild_id in [nil, 0],
    do: {:error, :guild_skill_unavailable}

  def validate_master(%PlayerState{guild_id: guild_id, character_id: char_id}) do
    case GuildManager.get(guild_id) do
      {:ok, %{master_char_id: ^char_id}} -> :ok
      _not_master_or_missing -> {:error, :guild_skill_unavailable}
    end
  end

  @doc """
  Warps up to `max_calls` online guild members (`:all` = no cap) next to the
  caster. Does nothing for a caster without a guild.
  """
  @spec summon_members(PlayerState.t(), pos_integer() | :all) :: :ok
  def summon_members(%PlayerState{} = caster, max_calls) do
    with {:ok, guild} <- fetch_guild(caster),
         {:ok, {x, y, map_name}} <-
           SpatialIndex.get_unit_position(:player, caster.character_id) do
      guild
      |> GuildState.members_by_slot()
      |> Enum.reduce_while(0, &summon_next(&1, &2, caster, max_calls, {map_name, x, y}))
    end

    :ok
  end

  defp summon_next(member, called, caster, max_calls, {map_name, x, y}) do
    cond do
      capped?(called, max_calls) -> {:halt, called}
      summon(caster, member, map_name, x, y) -> {:cont, called + 1}
      true -> {:cont, called}
    end
  end

  @doc """
  Arms the cooldowns of an Urgent Call's effect (`GuildCooldown.rearm/4`),
  which runs only for a caster whose guild exists.
  """
  @spec rearm_cooldowns(PlayerState.t(), pos_integer(), Definition.t(), integer()) ::
          PlayerState.t()
  def rearm_cooldowns(caster, level, definition, now) do
    case fetch_guild(caster) do
      {:ok, _guild} -> GuildCooldown.rearm(caster, definition, level, now)
      :error -> caster
    end
  end

  defp fetch_guild(%PlayerState{guild_id: guild_id}) when guild_id in [nil, 0], do: :error

  defp fetch_guild(%PlayerState{guild_id: guild_id}) do
    case GuildManager.get(guild_id) do
      {:ok, guild} -> {:ok, guild}
      {:error, :not_found} -> :error
    end
  end

  defp capped?(_called, :all), do: false
  defp capped?(called, max_calls), do: called >= max_calls

  defp summon(%PlayerState{character_id: caster_id}, %{char_id: caster_id}, _map, _x, _y),
    do: false

  defp summon(_caster, %{char_id: char_id, slot: slot}, map_name, x, y) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{} = member, pid}} ->
        if summonable?(member) do
          {dx, dy} = ring_cell(map_name, x, y, slot)
          PlayerSession.warp(pid, map_name, x + dx, y + dy)
          true
        else
          false
        end

      {:error, :not_found} ->
        false
    end
  end

  defp summonable?(%PlayerState{action_state: :dead}), do: false

  defp summonable?(%PlayerState{map_name: map_name}),
    do: not MapFlags.get(map_name, :nowarp) or Rules.ground?(map_name)

  defp ring_cell(map_name, x, y, slot) do
    {dx, dy} = Enum.at(@ring, rem(slot, length(@ring)))
    if Cell.traversable?(map_name, x + dx, y + dy), do: {dx, dy}, else: {0, 0}
  end
end
