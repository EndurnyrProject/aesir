defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea do
  @moduledoc """
  Shared helpers for master-cast guild area skills.

  `validate_master/1` re-asserts guild-master-ness and the GvG-only config
  gate inside the skill module so every entry point (including item and auto
  casts, which skip the learned check by contract) enforces them.
  `guildmates_in_range/2` resolves the same-guild players (caster included,
  matching the reference splash) around the caster's current cell.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Validates that the caster is his guild's master and the GvG gate allows the cast."
  @spec validate_master(PlayerState.t()) :: :ok | {:error, :not_guild_master | :not_gvg_ground}
  def validate_master(%PlayerState{guild_id: guild_id}) when guild_id in [nil, 0],
    do: {:error, :not_guild_master}

  def validate_master(%PlayerState{guild_id: guild_id, character_id: char_id}) do
    cond do
      Config.guild_skills_gvg_only() -> {:error, :not_gvg_ground}
      match?({:ok, %{master_char_id: ^char_id}}, GuildManager.get(guild_id)) -> :ok
      true -> {:error, :not_guild_master}
    end
  end

  @doc """
  Char ids of same-guild players (caster included) within `radius` cells of
  the caster's live position.
  """
  @spec guildmates_in_range(PlayerState.t(), pos_integer()) :: [non_neg_integer()]
  def guildmates_in_range(%PlayerState{character_id: char_id, guild_id: guild_id}, radius) do
    case SpatialIndex.get_unit_position(:player, char_id) do
      {:ok, {x, y, map_name}} ->
        :player
        |> SpatialIndex.get_units_in_range(map_name, x, y, radius)
        |> Enum.filter(&same_guild?(&1, guild_id))

      {:error, :not_found} ->
        []
    end
  end

  @doc """
  Applies a timed status to every guildmate in range of the caster.

  Targets other than the caster get `owner_refresh: :notify` since the apply
  runs in the caster's session, not theirs.
  """
  @spec buff_guildmates(PlayerState.t(), pos_integer(), atom(), keyword()) :: :ok
  def buff_guildmates(%PlayerState{character_id: caster_id} = caster, radius, status_id, params) do
    caster
    |> guildmates_in_range(radius)
    |> Enum.each(fn char_id ->
      refresh = if char_id == caster_id, do: [], else: [owner_refresh: :notify]
      StatusInterpreter.apply_status(:player, char_id, status_id, params ++ refresh)
    end)
  end

  @doc """
  Restores a percentage of a player's max HP and SP (async, via that player's
  own session).
  """
  @spec percent_restore(non_neg_integer(), pos_integer(), pos_integer(), non_neg_integer()) ::
          :ok
  def percent_restore(char_id, hp_percent, sp_percent, source_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{stats: %{derived_stats: derived}}, pid}} ->
        Combat.apply_heal(:player, char_id, div(derived.max_hp * hp_percent, 100), source_id)
        PlayerSession.restore_sp(pid, div(derived.max_sp * sp_percent, 100))

      _other ->
        :ok
    end
  end

  defp same_guild?(char_id, guild_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{guild_id: ^guild_id}, _pid}} -> true
      _other -> false
    end
  end
end
