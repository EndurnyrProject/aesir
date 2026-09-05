defmodule Aesir.ZoneServer.Mmo.Woe.Rules do
  @moduledoc """
  Finite siege-ground rules shared by WoE consumers.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @emperium_mob_id 1288
  @guild_approval_skill_id 10_000
  @triple_attack_skill_id 263
  @shared_skill_bans [26, 27, 87, 150, 219]

  @doc "Returns whether a map uses siege-ground rules."
  @spec ground?(String.t()) :: boolean()
  def ground?(map_name) do
    MapFlags.get(map_name, :gvg) or MapFlags.get(map_name, :gvg_castle)
  end

  @doc "Returns whether siege is currently active on a map."
  @spec active?(String.t()) :: boolean()
  def active?(map_name), do: MapFlags.get(map_name, :gvg)

  @doc "Validates whether an attack may target the live Emperium."
  @spec validate_target(Combatant.t(), Combatant.t(), map()) :: :ok | {:error, atom()}
  def validate_target(
        attacker,
        %{unit_type: :mob, monster_id: @emperium_mob_id} = target,
        hit_info
      )
      when is_map(attacker) and is_map(hit_info) do
    with :ok <- ensure_active(target.map_name),
         {:ok, castle} <- fetch_castle(target.map_name),
         castle_state <- CastleStore.get(castle.id),
         :ok <- ensure_live_emperium(castle_state, target.unit_id),
         guild_id <- attacker_guild_id(attacker),
         :ok <- ensure_guild(guild_id),
         {:ok, guild} <- fetch_guild(guild_id),
         :ok <- ensure_approval(guild),
         :ok <- ensure_non_owner(castle_state.owner_guild_id, guild_id) do
      ensure_attack_allowed(hit_info)
    end
  end

  def validate_target(attacker, target, hit_info)
      when is_map(attacker) and is_map(target) and is_map(hit_info),
      do: :ok

  @doc "Returns the siege-ground damage percentage for hit metadata."
  @spec damage_rate(map()) :: pos_integer()
  def damage_rate(%{skill_id: skill_id}) when is_integer(skill_id), do: 60
  def damage_rate(_hit_info), do: 80

  @doc "Returns whether a skill may be cast on the map under siege-ground rules."
  @spec skill_allowed?(pos_integer(), String.t()) :: boolean()
  def skill_allowed?(skill_id, map_name) do
    not ground?(map_name) or skill_id not in skill_bans(GameMode.mode())
  end

  @doc "Returns whether an item may be used on the map under siege-ground rules."
  @spec item_allowed?(pos_integer(), String.t()) :: boolean()
  def item_allowed?(item_id, map_name) do
    not ground?(map_name) or item_id not in item_bans(GameMode.mode())
  end

  @doc "Returns whether a status may be applied on the map under siege-ground rules."
  @spec status_allowed?(atom(), String.t()) :: boolean()
  def status_allowed?(status, map_name) do
    not ground?(map_name) or status != :sc_endure
  end

  defp ensure_active(map_name) do
    if active?(map_name), do: :ok, else: {:error, :siege_inactive}
  end

  defp fetch_castle(map_name) do
    case CastleDb.by_map(map_name) do
      {:ok, castle} -> {:ok, castle}
      :error -> {:error, :stale_emperium}
    end
  end

  defp ensure_live_emperium(%{siege_active?: false}, _unit_id),
    do: {:error, :siege_inactive}

  defp ensure_live_emperium(%{emperium_unit_id: unit_id}, unit_id), do: :ok
  defp ensure_live_emperium(_castle_state, _unit_id), do: {:error, :stale_emperium}

  defp attacker_guild_id(%Combatant{
         unit_type: :homunculus,
         social_root: {:player, owner_id}
       }) do
    case UnitRegistry.get_unit(:player, owner_id) do
      {:ok, {_module, owner_state, _pid}} -> Map.get(owner_state, :guild_id)
      {:error, :not_found} -> nil
    end
  end

  defp attacker_guild_id(attacker), do: Map.get(attacker, :guild_id)

  defp ensure_guild(guild_id) when is_integer(guild_id) and guild_id > 0, do: :ok
  defp ensure_guild(_guild_id), do: {:error, :guild_required}

  defp fetch_guild(guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, guild} -> {:ok, guild}
      {:error, :not_found} -> {:error, :approval_required}
    end
  end

  defp ensure_approval(guild) do
    if GuildState.skill_level(guild, @guild_approval_skill_id) > 0,
      do: :ok,
      else: {:error, :approval_required}
  end

  defp ensure_non_owner(guild_id, guild_id), do: {:error, :owner_guild}
  defp ensure_non_owner(_owner_guild_id, _attacker_guild_id), do: :ok

  defp ensure_attack_allowed(hit_info) do
    case Map.get(hit_info, :skill_id) do
      nil -> :ok
      @triple_attack_skill_id -> allow_pre_renewal_only()
      _skill_id -> {:error, :skill_not_allowed}
    end
  end

  defp allow_pre_renewal_only do
    if GameMode.mode() == :pre_renewal, do: :ok, else: {:error, :skill_not_allowed}
  end

  defp skill_bans(:renewal), do: @shared_skill_bans
  defp skill_bans(:pre_renewal), do: [1013 | @shared_skill_bans]

  defp item_bans(:renewal), do: [605, 14_529]
  defp item_bans(:pre_renewal), do: [14_529]
end
