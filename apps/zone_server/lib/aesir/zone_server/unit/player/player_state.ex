defmodule Aesir.ZoneServer.Unit.Player.PlayerState do
  @moduledoc """
  Represents the state of a player in the game world.
  Implements the Entity behaviour for status effect calculations.
  """

  @behaviour Aesir.ZoneServer.Unit.Entity

  @type direction :: 0..7
  @type movement_state :: :just_spawned | :standing | :moving

  alias Aesir.ZoneServer.Unit.Player.Stats

  defstruct [
    # Position & Movement
    :x,
    :y,
    :map_name,
    :dir,

    # Movement state machine
    # :just_spawned | :standing | :moving
    :movement_state,

    # Movement state
    :walk_path,
    :walk_speed,
    :walk_start_time,
    :is_walking,
    # Track how much of the path cost we've consumed
    :path_progress,

    # Visibility
    :view_range,
    # MapSet of char_ids currently visible
    :visible_players,
    # Last grid cell for visibility check
    :last_visibility_cell,

    # State flags
    :is_sitting,
    :is_dead,

    # Combat/Interaction
    :target_id,
    :is_trading,
    :is_vending,
    :is_chatting,

    # Character Stats
    :stats,

    # Inventory
    :inventory_items
  ]

  @doc """
  Creates a new PlayerState from a Character's last known position.
  """
  def new(%Aesir.Commons.Models.Character{} = character) do
    %__MODULE__{
      map_name: character.last_map,
      x: character.last_x,
      y: character.last_y,
      dir: 0,

      # Movement state machine - starts as just_spawned
      movement_state: :just_spawned,

      # Movement defaults
      walk_path: [],
      walk_speed: 150,
      is_walking: false,
      path_progress: 0,

      # Visibility defaults
      view_range: 14,
      visible_players: MapSet.new(),
      last_visibility_cell: nil,

      # State defaults
      target_id: nil,
      is_sitting: false,
      is_dead: false,
      is_trading: false,
      is_vending: false,
      is_chatting: false,

      # Character Stats
      stats: Stats.from_character(character),

      # Inventory (will be loaded separately)
      inventory_items: []
    }
  end

  @doc """
  Updates position in the game state.
  """
  def update_position(%__MODULE__{} = state, x, y) do
    %{state | x: x, y: y}
  end

  @doc """
  Sets the inventory items for the player state.
  """
  def set_inventory(%__MODULE__{} = state, inventory_items) do
    %{state | inventory_items: inventory_items}
  end

  @doc """
  Sets a movement path and starts walking.
  Transitions state to :moving when path is set.
  """
  def set_path(%__MODULE__{} = state, path) when is_list(path) do
    if length(path) > 0 do
      %{
        state
        | walk_path: path,
          is_walking: true,
          walk_start_time: System.system_time(:millisecond),
          # Reset progress when starting new path
          path_progress: 0,
          # Transition to moving state
          movement_state: :moving
      }
    else
      %{state | walk_path: path, is_walking: false, path_progress: 0, movement_state: :standing}
    end
  end

  @doc """
  Stops walking and clears the path.
  Transitions state to :standing.
  """
  def stop_walking(%__MODULE__{} = state) do
    %{
      state
      | walk_path: [],
        is_walking: false,
        walk_start_time: nil,
        path_progress: 0,
        # Transition to standing state
        movement_state: :standing
    }
  end

  @doc """
  Transitions from :just_spawned to :standing.
  Should be called after initial spawn packets are sent.
  """
  def mark_spawn_complete(%__MODULE__{movement_state: :just_spawned} = state) do
    %{state | movement_state: :standing}
  end

  def mark_spawn_complete(%__MODULE__{} = state), do: state

  @doc """
  Updates direction based on movement.
  """
  def update_direction(%__MODULE__{} = state, new_dir) when new_dir in 0..7 do
    %{state | dir: new_dir}
  end

  # Entity behaviour implementations

  @impl Aesir.ZoneServer.Unit.Entity
  def get_race(%__MODULE__{}), do: :human

  @impl Aesir.ZoneServer.Unit.Entity
  def get_element(%__MODULE__{}), do: {:neutral, 1}

  @impl Aesir.ZoneServer.Unit.Entity
  def is_boss?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit.Entity
  def get_size(%__MODULE__{}), do: :medium

  @impl Aesir.ZoneServer.Unit.Entity
  def get_stats(%__MODULE__{stats: stats}) do
    # Extract the relevant stats for resistance calculations
    %{
      vit: stats.base_stats.vit,
      int: stats.base_stats.int,
      dex: stats.base_stats.dex,
      luk: stats.base_stats.luk,
      # MDEF might come from derived stats or modifiers
      mdef: Map.get(stats.combat_stats, :mdef, 0)
    }
  end

  @impl Aesir.ZoneServer.Unit.Entity
  def get_entity_info(%__MODULE__{} = state) do
    {element, element_level} = get_element(state)

    %{
      race: get_race(state),
      element: element,
      element_level: element_level,
      boss_flag: is_boss?(state),
      size: get_size(state),
      stats: get_stats(state),
      entity_type: :player
    }
  end
end
