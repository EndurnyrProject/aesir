defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea do
  @moduledoc """
  Shared helpers for master-cast guild area skills (Battle Orders,
  Regeneration, Restore, Emergency Move).

  `validate_master/1` is the cast-begin check: GvG ground (a GvG map or castle
  of either kind, War of Emperium TE included, whether or not the siege runs)
  first, which fails the cast, then the caster being his guild's master, which
  drops it silently.
  The effect needs only the caster's guild: `guildmates_in_range/2` resolves
  the same-guild players (caster included) in the square around the caster's
  current cell. `rearm_cooldowns/4` arms the cooldowns the effect sets.
  """

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildCooldown
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Refuses the cast off GvG ground (`:not_gvg_ground`, a reported failure) and
  drops it silently (`:guild_skill_unavailable`) when the caster is not his
  guild's master.
  """
  @spec validate_master(PlayerState.t()) ::
          :ok | {:error, :not_gvg_ground | :guild_skill_unavailable}
  def validate_master(%PlayerState{map_name: map_name} = caster) do
    if MapFlags.gvg2?(map_name), do: master(caster), else: {:error, :not_gvg_ground}
  end

  defp master(%PlayerState{guild_id: guild_id}) when guild_id in [nil, 0],
    do: {:error, :guild_skill_unavailable}

  defp master(%PlayerState{guild_id: guild_id, character_id: char_id}) do
    case GuildManager.get(guild_id) do
      {:ok, %{master_char_id: ^char_id}} -> :ok
      _not_master_or_missing -> {:error, :guild_skill_unavailable}
    end
  end

  @doc """
  Char ids of same-guild players (caster included) within `radius` cells of
  the caster's live position, counted as a square, leaving out invincible
  players. Empty for a guildless caster.
  """
  @spec guildmates_in_range(PlayerState.t(), pos_integer()) :: [non_neg_integer()]
  def guildmates_in_range(%PlayerState{guild_id: guild_id}, _radius)
      when guild_id in [nil, 0],
      do: []

  def guildmates_in_range(%PlayerState{character_id: char_id, guild_id: guild_id}, radius) do
    case SpatialIndex.get_unit_position(:player, char_id) do
      {:ok, {x, y, map_name}} ->
        :player
        |> SpatialIndex.get_units_in_area(
          map_name,
          x - radius,
          y - radius,
          x + radius,
          y + radius
        )
        |> Enum.filter(&(same_guild?(&1, guild_id) and not Invincibility.active?({:player, &1})))

      _missing ->
        []
    end
  end

  @doc """
  Arms the cooldowns of a guild area skill's effect (`GuildCooldown.rearm/4`),
  which runs only for a caster in a guild.
  """
  @spec rearm_cooldowns(PlayerState.t(), pos_integer(), Definition.t(), integer()) ::
          PlayerState.t()
  def rearm_cooldowns(%PlayerState{guild_id: guild_id} = caster, _level, _definition, _now)
      when guild_id in [nil, 0],
      do: caster

  def rearm_cooldowns(caster, level, definition, now),
    do: GuildCooldown.rearm(caster, definition, level, now)

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
