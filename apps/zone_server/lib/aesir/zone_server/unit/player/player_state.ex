defmodule Aesir.ZoneServer.Unit.Player.PlayerState do
  @moduledoc """
  Represents the state of a player in the game world.
  Implements the Entity behaviour for status effect calculations.
  """

  @behaviour Aesir.ZoneServer.Unit

  @type direction :: 0..7
  @type movement_state :: :standing | :moving
  @type action_state ::
          :idle
          | :moving
          | :combat_moving
          | :attacking
          | :sitting
          | :dead
          | :trading
          | :vending

  @type t :: %__MODULE__{
          character_id: integer(),
          character_name: String.t(),
          account_id: integer(),
          process_pid: pid() | nil,
          x: integer(),
          y: integer(),
          map_name: String.t(),
          dir: direction(),
          action_state: action_state(),
          state_context: map(),
          movement_state: movement_state(),
          walk_path: list({integer(), integer()}),
          walk_speed: integer(),
          movement_intent: :none | :normal | :combat,
          view_range: integer(),
          visible_players: MapSet.t(),
          visible_mobs: MapSet.t(),
          last_visibility_cell: {integer(), integer()} | nil,
          target_id: integer() | nil,
          combat_target_id: integer() | nil,
          combat_action_type: integer() | nil,
          last_target_position: {integer(), integer()} | nil,
          last_attack_timestamp: integer(),
          continuous_attack_timer: reference() | nil,
          stats: PlayerStats.t(),
          inventory_items: list()
        }

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  defstruct [
    # Character identification
    :character_id,
    :character_name,
    :account_id,
    :process_pid,

    # Position & Movement
    :x,
    :y,
    :map_name,
    :dir,

    # Action state machine
    # Represents the primary action state of the player
    :action_state,

    # State context for current action
    # Stores state-specific data like combat intent
    :state_context,

    # Movement state machine
    # :standing | :moving (kept separate for movement mechanics)
    :movement_state,

    # Movement state
    :walk_path,
    :walk_speed,

    # Movement intent - why are we moving?
    # :none | :normal | :combat
    :movement_intent,

    # Visibility
    :view_range,
    # MapSet of char_ids currently visible
    :visible_players,
    # MapSet of mob_ids currently visible
    :visible_mobs,
    # Last grid cell for visibility check
    :last_visibility_cell,

    # Combat state
    :target_id,
    :combat_target_id,
    :combat_action_type,
    :last_target_position,
    :last_attack_timestamp,
    :continuous_attack_timer,

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
      character_id: character.id,
      character_name: character.name,
      account_id: character.account_id,
      # Will be set later if needed
      process_pid: nil,
      map_name: character.last_map,
      x: character.last_x,
      y: character.last_y,
      dir: 0,

      # Action state machine - starts as idle
      action_state: :idle,
      state_context: %{},

      # Movement state machine - starts as standing
      movement_state: :standing,

      # Movement defaults
      walk_path: [],
      walk_speed: 150,
      movement_intent: :none,

      # Visibility defaults
      view_range: 14,
      visible_players: MapSet.new(),
      visible_mobs: MapSet.new(),
      last_visibility_cell: nil,

      # Combat defaults
      target_id: nil,
      combat_target_id: nil,
      combat_action_type: nil,
      last_target_position: nil,
      last_attack_timestamp: 0,

      # Character Stats
      stats: PlayerStats.from_character(character),

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
          movement_state: :moving
      }
    else
      %{state | walk_path: path, movement_state: :standing}
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
        movement_state: :standing
    }
  end

  @doc """
  Mark spawn as complete. No-op now that we start in :standing state.
  """
  def mark_spawn_complete(%__MODULE__{} = state), do: state

  @doc """
  Updates direction based on movement.
  """
  def update_direction(%__MODULE__{} = state, new_dir) when new_dir in 0..7 do
    %{state | dir: new_dir}
  end

  @doc """
  Sets the process PID for this player state.
  """
  def set_process_pid(%__MODULE__{} = state, pid) when is_pid(pid) do
    %{state | process_pid: pid}
  end

  @doc """
  Transitions to a new action state.
  Validates the transition and updates state context as needed.
  """
  @spec transition_to(t(), action_state(), map()) :: {:ok, t()} | {:error, :invalid_transition}
  def transition_to(%__MODULE__{action_state: current} = state, new_state, context \\ %{}) do
    if can_transition?(current, new_state) do
      updated_state = %{
        state
        | action_state: new_state,
          state_context: context
      }

      # Handle state-specific setup
      updated_state = handle_state_entry(updated_state, new_state)
      {:ok, updated_state}
    else
      {:error, :invalid_transition}
    end
  end

  @doc """
  Sets combat intent for move-to-attack behavior.
  """
  @spec set_combat_intent(t(), integer(), integer(), {integer(), integer()} | nil) :: t()
  def set_combat_intent(%__MODULE__{} = state, target_id, action_type, target_pos \\ nil) do
    %{
      state
      | combat_target_id: target_id,
        combat_action_type: action_type,
        last_target_position: target_pos,
        movement_intent: :combat
    }
  end

  @doc """
  Clears combat intent.
  """
  @spec clear_combat_intent(t()) :: t()
  def clear_combat_intent(%__MODULE__{} = state) do
    %{
      state
      | combat_target_id: nil,
        combat_action_type: nil,
        last_target_position: nil,
        movement_intent: if(state.movement_state == :moving, do: :normal, else: :none)
    }
  end

  @doc """
  Checks if player is moving for combat purposes.
  """
  @spec combat_moving?(t()) :: boolean()
  def combat_moving?(%__MODULE__{action_state: :combat_moving}), do: true
  def combat_moving?(_), do: false

  @doc """
  Checks if a state transition is valid.
  """
  @spec can_transition?(action_state(), action_state()) :: boolean()
  def can_transition?(from, to) do
    cond do
      # Universal rules
      from == to -> true
      to == :dead -> true
      # Dead state rules
      from == :dead -> to == :idle
      # State-specific rules
      true -> valid_state_transition?(from, to)
    end
  end

  defp valid_state_transition?(from, to) do
    case from do
      :idle -> valid_from_idle?(to)
      :moving -> valid_from_moving?(to)
      :combat_moving -> valid_from_combat_moving?(to)
      :attacking -> valid_from_attacking?(to)
      :sitting -> valid_from_sitting?(to)
      :trading -> valid_from_trading?(to)
      :vending -> valid_from_vending?(to)
      _ -> false
    end
  end

  defp valid_from_idle?(to),
    do: to in [:moving, :combat_moving, :attacking, :sitting, :trading, :vending]

  defp valid_from_moving?(to), do: to in [:idle, :combat_moving, :attacking]
  defp valid_from_combat_moving?(to), do: to in [:idle, :attacking, :moving]
  defp valid_from_attacking?(to), do: to in [:idle, :combat_moving]
  defp valid_from_sitting?(to), do: to == :idle
  defp valid_from_trading?(to), do: to == :idle
  defp valid_from_vending?(to), do: to == :idle

  # Private helper to handle state entry logic
  defp handle_state_entry(state, :idle) do
    # Clear combat intent when becoming idle
    clear_combat_intent(state)
  end

  defp handle_state_entry(state, :moving) do
    # Set movement intent to normal if not combat
    if state.movement_intent == :none do
      %{state | movement_intent: :normal}
    else
      state
    end
  end

  defp handle_state_entry(state, :combat_moving) do
    # Ensure movement intent is combat
    %{state | movement_intent: :combat}
  end

  defp handle_state_entry(state, _new_state), do: state

  @impl Aesir.ZoneServer.Unit
  def get_unit_id(%__MODULE__{character_id: character_id}), do: character_id

  @impl Aesir.ZoneServer.Unit
  def get_unit_type(%__MODULE__{}), do: :player

  @impl Aesir.ZoneServer.Unit
  def get_process_pid(%__MODULE__{process_pid: pid}), do: pid

  @impl Aesir.ZoneServer.Unit
  def get_race(%__MODULE__{}), do: :human

  @impl Aesir.ZoneServer.Unit
  def get_element(%__MODULE__{}), do: {:neutral, 1}

  @impl Aesir.ZoneServer.Unit
  def is_boss?(%__MODULE__{}), do: false

  @impl Aesir.ZoneServer.Unit
  def get_size(%__MODULE__{}), do: :medium

  @impl Aesir.ZoneServer.Unit
  def get_stats(%__MODULE__{stats: stats}) do
    PlayerStats.to_formula_map(stats)
  end

  @impl Aesir.ZoneServer.Unit
  def get_entity_info(%__MODULE__{} = state) do
    Unit.build_entity_info(__MODULE__, state)
    |> Map.put(:entity_type, :player)
  end

  @impl Aesir.ZoneServer.Unit
  def to_combatant(%__MODULE__{} = state) do
    Combatant.new!(%{
      unit_id: state.character_id,
      unit_type: :player,
      gid: state.account_id,
      base_stats: state.stats.base_stats,
      combat_stats: state.stats.combat_stats,
      progression: state.stats.progression,
      element: {:neutral, 1},
      race: :demi_human,
      size: :medium,
      weapon: %{
        type: :one_handed_sword,
        element: :neutral,
        size: SizeModifiers.weapon_size(:sword)
      },
      attack_range: WeaponTypes.get_attack_range(:one_handed_sword),
      position: {state.x, state.y},
      map_name: state.map_name
    })
  end
end
