defmodule Aesir.ZoneServer.Events.Player do
  @moduledoc """
  Player lifecycle event broadcasting.
  Handles spawn, despawn, and state change notifications.
  """

  alias Phoenix.PubSub
  alias Aesir.ZoneServer.Geometry

  @pubsub Aesir.PubSub

  @doc """
  Broadcasts that a player has spawned in the world.
  Includes full player data for initial visibility.
  """
  def broadcast_spawn(character, game_state) do
    {cx, cy} = Geometry.to_cell_coords(game_state.x, game_state.y)

    PubSub.broadcast(
      @pubsub,
      cell_topic(game_state.map_name, cx, cy),
      {:player_spawned, build_spawn_data(character, game_state)}
    )
  end

  @doc """
  Broadcasts that a player has despawned (logout/disconnect).
  """
  def broadcast_despawn(character_id, game_state) do
    {cx, cy} = Geometry.to_cell_coords(game_state.x, game_state.y)

    PubSub.broadcast(
      @pubsub,
      cell_topic(game_state.map_name, cx, cy),
      {:player_despawned, character_id}
    )
  end

  @doc """
  Broadcasts that a player has changed maps.
  """
  def broadcast_map_change(character_id, from_map, from_x, from_y, to_map) do
    {cx, cy} = Geometry.to_cell_coords(from_x, from_y)

    PubSub.broadcast(
      @pubsub,
      cell_topic(from_map, cx, cy),
      {:player_map_change, character_id, to_map}
    )
  end

  @doc """
  Subscribes to player events for a specific map.
  """
  def subscribe_to_map(map_name) do
    PubSub.subscribe(@pubsub, "map:#{map_name}")
  end

  defp cell_topic(map_name, cell_x, cell_y) do
    "map:#{map_name}:cell:#{cell_x}:#{cell_y}"
  end

  defp build_spawn_data(character, game_state) do
    %{
      char_id: character.id,
      account_id: character.account_id,
      name: character.name,
      job_id: character.class,
      level: character.base_level,
      # Position
      x: game_state.x,
      y: game_state.y,
      dir: game_state.dir,
      # Appearance
      hair: character.hair,
      hair_color: character.hair_color,
      clothes_color: character.clothes_color,
      head_top: character.head_top,
      head_mid: character.head_mid,
      head_bottom: character.head_bottom,
      weapon: character.weapon,
      shield: character.shield,
      robe: character.robe
    }
  end
end

