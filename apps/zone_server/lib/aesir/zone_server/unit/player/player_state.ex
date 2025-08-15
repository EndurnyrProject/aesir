defmodule Aesir.ZoneServer.Unit.Player.PlayerState do
  @type direction :: 0..7

  defstruct [
    # Position & Movement
    :x,
    :y,
    :map_name,
    :dir,

    # Movement state
    :walk_path,
    :walk_speed,
    :is_walking,

    # Visibility
    :view_range,
    :subscribed_cells,

    # State flags
    :is_sitting,
    :is_dead,

    # Combat/Interaction
    :target_id,
    :is_trading,
    :is_vending,
    :is_chatting
  ]

  @doc """
  Creates a new PlayerState from a Character's last known position.
  """
  def new(%Aesir.Commons.Models.Character{} = character) do
    %__MODULE__{
      # Position from last known location
      map_name: character.last_map,
      x: character.last_x,
      y: character.last_y,
      dir: 0,

      # Movement defaults
      walk_path: [],
      walk_speed: 150,
      is_walking: false,

      # Visibility defaults
      view_range: 14,
      subscribed_cells: [],

      # State defaults
      is_sitting: false,
      is_dead: false,
      target_id: nil,
      is_trading: false,
      is_vending: false,
      is_chatting: false
    }
  end

  @doc """
  Updates position in the game state.
  """
  def update_position(%__MODULE__{} = state, x, y) do
    %{state | x: x, y: y}
  end

  @doc """
  Sets a movement path and starts walking.
  """
  def set_path(%__MODULE__{} = state, path) when is_list(path) do
    %{state | walk_path: path, is_walking: length(path) > 0}
  end

  @doc """
  Stops walking and clears the path.
  """
  def stop_walking(%__MODULE__{} = state) do
    %{state | walk_path: [], is_walking: false}
  end

  @doc """
  Updates direction based on movement.
  """
  def update_direction(%__MODULE__{} = state, new_dir) when new_dir in 0..7 do
    %{state | dir: new_dir}
  end
end
