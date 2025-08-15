defmodule Aesir.ZoneServer.Events.Movement do
  @moduledoc """
  Movement-related event broadcasting.
  Handles player movement notifications across the game world.
  """

  alias Phoenix.PubSub
  alias Aesir.ZoneServer.Geometry

  @pubsub Aesir.PubSub

  @doc """
  Broadcasts that a player has started moving.
  """
  def broadcast_move_start(character_id, game_state, from_x, from_y, path) do
    cells = affected_cells(from_x, from_y, game_state.x, game_state.y)

    Enum.each(cells, fn {cx, cy} ->
      PubSub.broadcast(
        @pubsub,
        cell_topic(game_state.map_name, cx, cy),
        {:player_move_start, character_id, from_x, from_y, path}
      )
    end)
  end

  @doc """
  Broadcasts a player position update during movement.
  """
  def broadcast_position_update(character_id, game_state, from_x, from_y) do
    cells = affected_cells(from_x, from_y, game_state.x, game_state.y)

    Enum.each(cells, fn {cx, cy} ->
      PubSub.broadcast(
        @pubsub,
        cell_topic(game_state.map_name, cx, cy),
        {:player_moved, character_id, from_x, from_y, game_state.x, game_state.y}
      )
    end)
  end

  @doc """
  Broadcasts that a player has stopped moving.
  """
  def broadcast_stop(character_id, game_state) do
    {cx, cy} = Geometry.to_cell_coords(game_state.x, game_state.y)

    PubSub.broadcast(
      @pubsub,
      cell_topic(game_state.map_name, cx, cy),
      {:player_stopped, character_id, game_state.x, game_state.y}
    )
  end

  @doc """
  Subscribes to movement events in specific cells.
  """
  def subscribe_to_cells(map_name, cells) do
    Enum.each(cells, fn {cx, cy} ->
      PubSub.subscribe(@pubsub, cell_topic(map_name, cx, cy))
    end)
  end

  @doc """
  Unsubscribes from movement events in specific cells.
  """
  def unsubscribe_from_cells(map_name, cells) do
    Enum.each(cells, fn {cx, cy} ->
      PubSub.unsubscribe(@pubsub, cell_topic(map_name, cx, cy))
    end)
  end

  defp cell_topic(map_name, cell_x, cell_y) do
    "map:#{map_name}:cell:#{cell_x}:#{cell_y}"
  end

  defp affected_cells(from_x, from_y, to_x, to_y) do
    from_cell = Geometry.to_cell_coords(from_x, from_y)
    to_cell = Geometry.to_cell_coords(to_x, to_y)

    if from_cell == to_cell do
      [from_cell]
    else
      [from_cell, to_cell] |> Enum.uniq()
    end
  end
end

