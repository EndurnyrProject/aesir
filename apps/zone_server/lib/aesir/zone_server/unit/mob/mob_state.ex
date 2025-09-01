defmodule Aesir.ZoneServer.Unit.Mob.MobState do
  @moduledoc """
  Represents the state of a mob entity in the game world.
  Implements the Entity behaviour for status effect calculations.
  Similar to PlayerState but for monsters with AI and combat capabilities.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Entity

  @behaviour Entity

  @type ai_state :: :idle | :alert | :combat | :chase | :return
  @type movement_state :: :standing | :moving | :returning

  typedstruct do
    # Core identification
    field :instance_id, integer(), enforce: true
    field :mob_id, integer(), enforce: true
    field :mob_data, MobDefinition.t(), enforce: true
    field :spawn_ref, MobSpawn.t(), enforce: true
    field :process_pid, pid(), default: nil

    # Position & Movement
    field :x, integer(), enforce: true
    field :y, integer(), enforce: true
    field :map_name, String.t(), enforce: true
    field :dir, integer(), default: 0

    # Movement state machine
    field :movement_state, movement_state(), default: :standing
    field :walk_path, list(), default: []
    field :walk_speed, integer(), default: 200
    field :target_position, {integer(), integer()}, default: nil

    # AI state machine
    field :ai_state, ai_state(), default: :idle
    field :target_id, integer(), default: nil
    field :last_ai_tick, integer(), default: nil
    field :aggro_list, map(), default: %{}
    field :last_action_time, integer(), default: nil
    field :last_movement_end_time, integer(), default: nil
    field :last_idle_movement_time, integer(), default: nil

    # Combat state
    field :hp, integer(), enforce: true
    field :max_hp, integer(), enforce: true
    field :sp, integer(), enforce: true
    field :max_sp, integer(), enforce: true
    field :is_dead, boolean(), default: false

    # Spatial awareness
    field :view_range, integer(), default: 12
    field :visible_entities, MapSet.t(), default: %MapSet{}

    # Lifecycle
    field :spawned_at, integer(), enforce: true
    field :last_damage_time, integer(), default: nil
    field :respawn_delay, integer(), default: 0

    # Status effects
    field :status_effects, map(), default: %{}
  end

  @doc """
  Creates a new mob state instance.
  """
  @spec new(integer(), MobDefinition.t(), MobSpawn.t(), String.t(), integer(), integer()) :: t()
  def new(instance_id, mob_data, spawn_ref, map_name, x, y) do
    current_time = System.system_time(:second)

    %__MODULE__{
      instance_id: instance_id,
      mob_id: mob_data.id,
      mob_data: mob_data,
      spawn_ref: spawn_ref,
      map_name: map_name,
      x: x,
      y: y,
      hp: mob_data.hp,
      max_hp: mob_data.hp,
      sp: mob_data.sp,
      max_sp: mob_data.sp,
      spawned_at: current_time,
      last_ai_tick: current_time,
      status_effects: %{},
      walk_speed: mob_data.walk_speed,
      view_range: calculate_view_range(mob_data),
      respawn_delay: spawn_ref.respawn_time
    }
  end

  @impl Entity
  def get_race(%__MODULE__{mob_data: mob_data}) do
    mob_data.race
  end

  @impl Entity
  def get_element(%__MODULE__{mob_data: mob_data}) do
    # Element is stored as a combined value in mob_data
    # We need to extract element type and level
    element_type = extract_element_type(mob_data.element)
    element_level = extract_element_level(mob_data.element)
    {element_type, element_level}
  end

  @impl Entity
  def is_boss?(%__MODULE__{mob_data: mob_data}) do
    :boss in (mob_data.modes || [])
  end

  @impl Entity
  def get_size(%__MODULE__{mob_data: mob_data}) do
    mob_data.size
  end

  @impl Entity
  def get_stats(%__MODULE__{mob_data: mob_data} = mob) do
    # Return stats in the format expected by status effect formulas
    %{
      str: mob_data.stats.str,
      agi: mob_data.stats.agi,
      vit: mob_data.stats.vit,
      int: mob_data.stats.int,
      dex: mob_data.stats.dex,
      luk: mob_data.stats.luk,
      base_level: mob_data.level,
      job_level: 1,
      hp: mob.hp,
      max_hp: mob.max_hp,
      sp: mob.sp,
      max_sp: mob.max_sp,
      atk: mob_data.atk_min,
      atk2: mob_data.atk_max,
      def: mob_data.def,
      mdef: mob_data.mdef,
      hit: calculate_hit(mob_data),
      flee: calculate_flee(mob_data),
      crit: calculate_crit(mob_data),
      aspd: calculate_aspd(mob_data)
    }
  end

  @impl Entity
  def get_entity_info(%__MODULE__{} = mob) do
    Entity.build_entity_info(__MODULE__, mob)
    |> Map.put(:entity_type, :mob)
  end

  @impl Entity
  def get_process_pid(%__MODULE__{process_pid: pid}), do: pid

  @impl Entity
  def get_unit_id(%__MODULE__{instance_id: instance_id}) do
    instance_id
  end

  @impl Entity
  def get_unit_type(_mob) do
    :mob
  end

  @impl Entity
  def get_custom_immunities(%__MODULE__{mob_data: mob_data}) do
    # Check mob modes for special immunities
    immunities = []

    immunities =
      if :plant in (mob_data.modes || []) do
        # Plant-type mobs are immune to many status effects
        [:stun, :freeze, :stone, :sleep | immunities]
      else
        immunities
      end

    immunities =
      if :undead in (mob_data.modes || []) do
        # Undead mobs have special immunities
        [:blessing, :increase_agi, :decrease_agi | immunities]
      else
        immunities
      end

    immunities
  end

  # State Management Functions

  @doc """
  Sets the process PID for this mob state.
  """
  @spec set_process_pid(t(), pid()) :: t()
  def set_process_pid(%__MODULE__{} = state, pid) when is_pid(pid) do
    %{state | process_pid: pid}
  end

  @doc """
  Updates position and handles movement state transitions.
  """
  @spec update_position(t(), integer(), integer()) :: t()
  def update_position(%__MODULE__{} = state, new_x, new_y) do
    %{state | x: new_x, y: new_y}
  end

  @doc """
  Sets a movement path and starts moving.
  """
  @spec set_path(t(), [{integer(), integer()}]) :: t()
  def set_path(%__MODULE__{} = state, path) when is_list(path) do
    if length(path) > 0 do
      %{
        state
        | walk_path: path,
          movement_state: :moving
      }
    else
      %{
        state
        | walk_path: path,
          movement_state: :standing
      }
    end
  end

  @doc """
  Stops movement and clears the path.
  """
  @spec stop_movement(t()) :: t()
  def stop_movement(%__MODULE__{} = state) do
    %{
      state
      | walk_path: [],
        movement_state: :standing,
        target_position: nil,
        last_movement_end_time: System.system_time(:millisecond)
    }
  end

  @doc """
  Sets the AI state.
  """
  @spec set_ai_state(t(), ai_state()) :: t()
  def set_ai_state(%__MODULE__{} = state, new_ai_state) do
    %{state | ai_state: new_ai_state, last_ai_tick: System.system_time(:second)}
  end

  @doc """
  Sets the combat target.
  """
  @spec set_target(t(), integer() | nil) :: t()
  def set_target(%__MODULE__{} = state, target_id) do
    %{state | target_id: target_id}
  end

  @doc """
  Adds or updates aggro for a target.
  """
  @spec add_aggro(t(), integer(), integer()) :: t()
  def add_aggro(%__MODULE__{aggro_list: aggro_list} = state, target_id, damage) do
    current_aggro = Map.get(aggro_list, target_id, 0)
    updated_aggro = Map.put(aggro_list, target_id, current_aggro + damage)
    %{state | aggro_list: updated_aggro}
  end

  @doc """
  Gets the highest aggro target.
  """
  @spec get_highest_aggro_target(t()) :: integer() | nil
  def get_highest_aggro_target(%__MODULE__{aggro_list: aggro_list}) do
    case Enum.max_by(aggro_list, fn {_id, aggro} -> aggro end, fn -> nil end) do
      {target_id, _aggro} -> target_id
      nil -> nil
    end
  end

  @doc """
  Clears all aggro.
  """
  @spec clear_aggro(t()) :: t()
  def clear_aggro(%__MODULE__{} = state) do
    %{state | aggro_list: %{}}
  end

  @doc """
  Marks the mob as dead.
  """
  @spec set_dead(t()) :: t()
  def set_dead(%__MODULE__{} = state) do
    %{
      state
      | is_dead: true,
        hp: 0,
        ai_state: :idle,
        target_id: nil,
        aggro_list: %{},
        movement_state: :standing,
        walk_path: []
    }
  end

  @doc """
  Updates direction based on movement or target.
  """
  @spec update_direction(t(), integer()) :: t()
  def update_direction(%__MODULE__{} = state, new_dir) when new_dir in 0..7 do
    %{state | dir: new_dir}
  end

  # Public API Functions

  @doc """
  Gets the mob's current position.
  """
  @spec get_position(t()) :: {integer(), integer()}
  def get_position(%__MODULE__{x: x, y: y}), do: {x, y}

  @doc """
  Gets the mob's current map.
  """
  @spec get_map(t()) :: String.t()
  def get_map(%__MODULE__{map_name: map_name}), do: map_name

  @doc """
  Applies damage to the mob.
  """
  @spec apply_damage(t(), integer()) :: {t(), :alive | :dead}
  def apply_damage(%__MODULE__{hp: current_hp} = mob, damage) do
    new_hp = max(0, current_hp - damage)
    updated_mob = %{mob | hp: new_hp}

    if new_hp == 0 do
      {updated_mob, :dead}
    else
      {updated_mob, :alive}
    end
  end

  @doc """
  Heals the mob.
  """
  @spec heal(t(), integer()) :: t()
  def heal(%__MODULE__{hp: current_hp, max_hp: max_hp} = mob, amount) do
    new_hp = min(max_hp, current_hp + amount)
    %{mob | hp: new_hp}
  end

  @doc """
  Checks if the mob should be aggressive towards players.
  """
  @spec aggressive?(t()) :: boolean()
  def aggressive?(%__MODULE__{mob_data: mob_data}) do
    :aggressive in (mob_data.modes || [])
  end

  @doc """
  Gets the mob's attack range.
  """
  @spec get_attack_range(t()) :: integer()
  def get_attack_range(%__MODULE__{mob_data: mob_data}) do
    mob_data.attack_range
  end

  @doc """
  Gets the mob's chase range.
  """
  @spec get_chase_range(t()) :: integer()
  def get_chase_range(%__MODULE__{mob_data: mob_data}) do
    mob_data.chase_range
  end

  # Private Helper Functions

  defp extract_element_type(element_value) do
    # Element type is stored in the lower byte
    element_type_id = rem(element_value, 20)

    element_map = %{
      0 => :neutral,
      1 => :water,
      2 => :earth,
      3 => :fire,
      4 => :wind,
      5 => :poison,
      6 => :holy,
      7 => :shadow,
      8 => :ghost,
      9 => :undead
    }

    Map.get(element_map, element_type_id, :neutral)
  end

  defp extract_element_level(element_value) do
    # Element level is stored in the upper part
    div(element_value, 20) + 1
  end

  defp calculate_hit(mob_data) do
    # Basic hit calculation based on level and DEX
    mob_data.level + mob_data.stats.dex
  end

  defp calculate_flee(mob_data) do
    # Basic flee calculation based on level and AGI
    mob_data.level + mob_data.stats.agi
  end

  defp calculate_crit(mob_data) do
    # Basic crit calculation based on LUK
    div(mob_data.stats.luk, 3)
  end

  defp calculate_aspd(mob_data) do
    # Convert attack delay to ASPD format
    # Lower attack_delay means faster attack speed
    max(100, 200 - div(mob_data.attack_delay, 10))
  end

  defp calculate_view_range(mob_data) do
    # Base view range, bosses have larger range
    if :boss in (mob_data.modes || []) do
      20
    else
      12
    end
  end
end
