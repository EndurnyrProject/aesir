defmodule Aesir.ZoneServer.Unit.Player.SpawnView do
  @moduledoc """
  Builds the outbound player `UnitSpawn` wire message from server-side player state.

  Mirrors `InventoryView` for the spawn domain: the single owner of the player
  spawn packet shape, folding the sprite-state aggregate (`StatusDisplay`), the
  equipped appearance (`Appearance`) and the guild identity into one `UnitSpawn`.
  """

  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Unit.Player.Appearance
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @doc """
  Builds the `UnitSpawn` describing `game_state`'s player for a nearby observer.
  """
  @spec build(PlayerState.t()) :: UnitSpawn.t()
  def build(game_state) do
    %{
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue
    } =
      StatusDisplay.spawn_state(:player, game_state.character_id)

    appearance = Appearance.spawn_fields(game_state.stats.equipment)

    {guild_id, guild_name, emblem_id} = guild_identity(game_state)

    %UnitSpawn{
      object_type: ObjectType.pc(),
      aid: game_state.account_id,
      gid: game_state.character_id,
      speed: game_state.walk_speed,
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue,
      job: game_state.stats.progression.job_id,
      head: game_state.hair,
      weapon: appearance.weapon,
      shield: appearance.shield,
      accessory: appearance.accessory,
      accessory2: appearance.accessory2,
      accessory3: appearance.accessory3,
      head_palette: game_state.hair_color,
      body_palette: game_state.clothes_color,
      head_dir: 0,
      robe: appearance.robe,
      guild_id: guild_id,
      guild_name: guild_name,
      emblem_id: emblem_id,
      spirit_sphere_count: SpiritSpheres.count(game_state.spirit_spheres),
      spirit_sphere_revision: game_state.spirit_sphere_revision,
      sex: sex_to_int(game_state.sex),
      x: game_state.x,
      y: game_state.y,
      dir: game_state.dir || 0,
      clevel: game_state.stats.progression.base_level,
      max_hp: game_state.stats.derived_stats.max_hp,
      hp: game_state.stats.current_state.hp,
      is_boss: false,
      name: game_state.character_name,
      moving: false
    }
  end

  # Resolves a player's guild identity for a spawn packet as
  # `{guild_id, guild_name, emblem_id}`. A guild-less player (guild_id 0) or a
  # stale/non-live guild entry defaults to an empty name and emblem 0; the real
  # guild_id is still carried for a member whose entry is not live.
  @spec guild_identity(map()) :: {non_neg_integer(), String.t(), non_neg_integer()}
  defp guild_identity(%{guild_id: 0}), do: {0, "", 0}

  defp guild_identity(%{guild_id: guild_id}) do
    case GuildManager.get(guild_id) do
      {:ok, %GuildState{name: name, emblem_id: emblem_id}} -> {guild_id, name, emblem_id}
      {:error, :not_found} -> {guild_id, "", 0}
    end
  end

  defp sex_to_int("F"), do: 0
  defp sex_to_int("M"), do: 1
  defp sex_to_int(_), do: 1
end
