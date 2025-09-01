defmodule Aesir.ZoneServer.Unit.Mob.AIStateMachine do
  @moduledoc """
  AI state machine logic for mobs.

  Implements different AI behaviors based on the mob's current state:
  - :idle - Default state, passive behavior
  - :alert - Detected potential targets, evaluating threats
  - :combat - Actively fighting a target
  - :chase - Pursuing a target that moved out of attack range
  - :return - Returning to spawn area after losing target

  This module separates AI logic from the MobSession GenServer for better
  organization and testability.
  """

  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Processes AI logic based on current state.
  Returns updated MobState.
  """
  @spec process_ai(MobState.t()) :: MobState.t()
  def process_ai(%MobState{ai_state: ai_state} = state) do
    current_time = System.system_time(:second)
    updated_state = %{state | last_ai_tick: current_time}

    case ai_state do
      :idle -> process_idle(updated_state)
      :alert -> process_alert(updated_state)
      :combat -> process_combat(updated_state)
      :chase -> process_chase(updated_state)
      :return -> process_return(updated_state)
    end
  end

  @doc """
  Checks if a mob should become aggressive towards nearby entities.
  """
  @spec check_aggro(MobState.t()) :: MobState.t()
  def check_aggro(%MobState{} = state) do
    if MobState.aggressive?(state) and state.ai_state == :idle do
      case find_nearby_targets(state) do
        [] ->
          state

        targets ->
          # Pick the closest target
          closest_target = select_closest_target(state, targets)

          state
          |> MobState.set_target(closest_target)
          |> MobState.set_ai_state(:alert)
      end
    else
      state
    end
  end

  @doc """
  Handles when a mob takes damage and should react.
  """
  @spec handle_damage_reaction(MobState.t(), integer() | nil) :: MobState.t()
  def handle_damage_reaction(state, attacker_id) do
    case {state.ai_state, attacker_id} do
      {:idle, nil} ->
        # Damaged but no attacker info, become alert
        MobState.set_ai_state(state, :alert)

      {:idle, attacker_id} when is_integer(attacker_id) ->
        # Attacked by specific entity, target them
        state
        |> MobState.set_target(attacker_id)
        |> MobState.set_ai_state(:combat)

      {_, attacker_id} when is_integer(attacker_id) ->
        # Already in combat, might switch targets based on aggro
        highest_aggro_target = MobState.get_highest_aggro_target(state)

        if highest_aggro_target != state.target_id do
          MobState.set_target(state, highest_aggro_target)
        else
          state
        end

      _ ->
        state
    end
  end

  @doc """
  Calculates movement toward a target position.
  Returns {new_x, new_y} coordinates for next step.
  """
  @spec calculate_movement(MobState.t(), integer(), integer()) :: {integer(), integer()}
  def calculate_movement(%MobState{x: current_x, y: current_y}, target_x, target_y) do
    # Simple movement - move one step toward target
    dx =
      cond do
        target_x > current_x -> 1
        target_x < current_x -> -1
        true -> 0
      end

    dy =
      cond do
        target_y > current_y -> 1
        target_y < current_y -> -1
        true -> 0
      end

    {current_x + dx, current_y + dy}
  end

  @doc """
  Checks if mob should return to spawn area.
  """
  @spec should_return_to_spawn?(MobState.t()) :: boolean()
  def should_return_to_spawn?(%MobState{} = state) do
    spawn_area = state.spawn_ref.spawn_area
    spawn_x = spawn_area.x
    spawn_y = spawn_area.y

    # Calculate distance from spawn
    distance_from_spawn = abs(state.x - spawn_x) + abs(state.y - spawn_y)

    # Return if too far from spawn (beyond chase range)
    max_distance = MobState.get_chase_range(state) * 2
    distance_from_spawn > max_distance
  end

  @doc """
  Checks if mob has reached its spawn area.
  """
  @spec at_spawn_area?(MobState.t()) :: boolean()
  def at_spawn_area?(%MobState{} = state) do
    spawn_area = state.spawn_ref.spawn_area
    spawn_x = spawn_area.x
    spawn_y = spawn_area.y

    abs(state.x - spawn_x) <= 2 and abs(state.y - spawn_y) <= 2
  end

  # Private Functions

  defp process_idle(state) do
    # Check for nearby enemies if aggressive
    check_aggro(state)
  end

  defp process_alert(state) do
    case state.target_id do
      nil ->
        # No target, return to idle
        MobState.set_ai_state(state, :idle)

      target_id ->
        cond do
          target_in_attack_range?(state, target_id) ->
            # Target in attack range, switch to combat
            MobState.set_ai_state(state, :combat)

          target_in_chase_range?(state, target_id) ->
            # Target in chase range, start chasing
            MobState.set_ai_state(state, :chase)

          true ->
            # Target too far, lose interest
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:idle)
        end
    end
  end

  defp process_combat(state) do
    case state.target_id do
      nil ->
        # No target, return to idle
        MobState.set_ai_state(state, :idle)

      target_id ->
        cond do
          target_in_attack_range?(state, target_id) ->
            # Can attack - perform attack logic here
            # For now, just stay in combat state
            state

          target_in_chase_range?(state, target_id) ->
            # Target moved out of attack range but still chaseable
            MobState.set_ai_state(state, :chase)

          should_return_to_spawn?(state) ->
            # Too far from spawn, return
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:return)

          true ->
            # Target lost, return to idle
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:idle)
        end
    end
  end

  defp process_chase(state) do
    case state.target_id do
      nil ->
        # No target, return to idle
        MobState.set_ai_state(state, :idle)

      target_id ->
        cond do
          target_in_attack_range?(state, target_id) ->
            # Caught up to target, switch to combat
            MobState.set_ai_state(state, :combat)

          target_in_chase_range?(state, target_id) ->
            # Continue chasing - move towards target
            # This would involve pathfinding in a full implementation
            state

          should_return_to_spawn?(state) ->
            # Too far from spawn, return
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:return)

          true ->
            # Lost target, return to spawn
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:return)
        end
    end
  end

  defp process_return(state) do
    if at_spawn_area?(state) do
      # Reached spawn, clear aggro and return to idle
      state
      |> MobState.clear_aggro()
      |> MobState.set_target(nil)
      |> MobState.set_ai_state(:idle)
    else
      # Continue returning to spawn
      # This would involve movement in a full implementation
      state
    end
  end

  defp find_nearby_targets(state) do
    view_range = state.view_range

    # Find players in range (primary targets)
    players =
      SpatialIndex.get_units_in_range(:player, state.map_name, state.x, state.y, view_range)

    # Could extend to include other target types (pets, mercenaries, etc.)
    players
  end

  defp select_closest_target(state, targets) when is_list(targets) do
    targets
    |> Enum.map(fn target_id ->
      case SpatialIndex.get_unit_position(:player, target_id) do
        {:ok, {target_x, target_y, _map}} ->
          distance = abs(state.x - target_x) + abs(state.y - target_y)
          {target_id, distance}

        _ ->
          # Invalid position, very high distance
          {target_id, 999_999}
      end
    end)
    |> Enum.min_by(fn {_id, distance} -> distance end)
    |> elem(0)
  end

  defp target_in_attack_range?(state, target_id) do
    attack_range = MobState.get_attack_range(state)
    target_in_range?(state, target_id, attack_range)
  end

  defp target_in_chase_range?(state, target_id) do
    chase_range = MobState.get_chase_range(state)
    target_in_range?(state, target_id, chase_range)
  end

  defp target_in_range?(state, target_id, range) do
    case SpatialIndex.get_unit_position(:player, target_id) do
      {:ok, {target_x, target_y, map_name}} when map_name == state.map_name ->
        distance = abs(state.x - target_x) + abs(state.y - target_y)
        distance <= range

      _ ->
        false
    end
  end
end
