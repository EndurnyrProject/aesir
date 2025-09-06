defmodule Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler do
  @moduledoc """
  Handles combat-related actions for players, including move-to-attack behavior.

  This module coordinates between the combat system and movement system to enable
  players to automatically move within range when attempting to attack distant targets.
  """

  require Logger

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Handles an attack request, initiating move-to-range if necessary.

  ## Parameters
    - state: The player session state
    - target_id: ID of the target to attack
    - action_type: Attack action type (0 = single, 7 = continuous)
    
  ## Returns
    - {:noreply, updated_state} with appropriate action state set
  """
  @spec handle_attack_request(map(), integer(), integer()) :: {:noreply, map()}
  def handle_attack_request(state, target_id, action_type) do
    Logger.info(
      "=== ATTACK REQUEST === Player #{state.character.id} requesting attack on target #{target_id} with action #{action_type}"
    )

    Logger.debug(
      "Current position: (#{state.game_state.x}, #{state.game_state.y}), State: #{state.game_state.action_state}"
    )

    # Store the action type in game state for later use
    state = %{state | game_state: %{state.game_state | combat_action_type: action_type}}

    # Check attack rate limiting
    attack_delay = AttackSpeed.calculate_delay_from_stats(state.game_state.stats)
    can_attack = AttackSpeed.can_attack?(state.game_state.last_attack_timestamp, attack_delay)

    Logger.debug("Attack delay: #{attack_delay}ms, Can attack: #{can_attack}")

    if can_attack do
      # Check if target is in range
      case check_attack_range(state, target_id) do
        {:in_range, distance} ->
          # Target is in range, execute attack immediately
          Logger.info("Target is in range (distance: #{distance}), executing immediate attack")
          execute_immediate_attack(state, target_id)

        {:out_of_range, target_pos} ->
          # Target is out of range, initiate combat movement
          Logger.info("Target out of range at #{inspect(target_pos)}, initiating combat movement")
          initiate_combat_movement(state, target_id, action_type, target_pos)

        {:error, reason} ->
          Logger.warning("Attack range check failed: #{inspect(reason)}")
          {:noreply, state}
      end
    else
      # Attack is too soon, rate limited
      Logger.debug("Attack rate limited for player #{state.character.id}")
      # TODO: Send error packet to client about attack cooldown
      {:noreply, state}
    end
  end

  @doc """
  Handles reaching the attack position after combat movement.
  Called by MovementHandler when a combat movement completes.
  """
  @spec handle_reached_attack_position(map()) :: {:noreply, map()}
  def handle_reached_attack_position(%{game_state: game_state} = state) do
    Logger.info(
      "=== REACHED ATTACK POSITION === combat_target_id: #{inspect(game_state.combat_target_id)}"
    )

    Logger.debug(
      "Current state: #{game_state.action_state}, Position: (#{game_state.x}, #{game_state.y})"
    )

    if game_state.combat_target_id do
      # Verify target is still in range and execute attack
      case check_attack_range(state, game_state.combat_target_id) do
        {:in_range, distance} ->
          Logger.info("Target confirmed in range at distance #{distance}, executing attack NOW")
          execute_immediate_attack(state, game_state.combat_target_id)

        {:out_of_range, target_pos} ->
          # Target moved away, need to move again
          Logger.debug("Target moved out of range to #{inspect(target_pos)}, recalculating path")

          initiate_combat_movement(
            state,
            game_state.combat_target_id,
            game_state.combat_action_type,
            target_pos
          )

        {:error, reason} ->
          # Target disappeared, clear combat intent
          Logger.debug("Target no longer available: #{reason}")
          updated_game_state = PlayerState.clear_combat_intent(game_state)
          {:ok, transitioned_state} = PlayerState.transition_to(updated_game_state, :idle)
          {:noreply, %{state | game_state: transitioned_state}}
      end
    else
      Logger.warning("Reached attack position but no combat_target_id set")
      {:noreply, state}
    end
  end

  @doc """
  Handles target movement during combat approach.
  Recalculates path if target moved significantly.
  """
  @spec handle_target_movement(map(), {integer(), integer()}) :: {:noreply, map()}
  def handle_target_movement(%{game_state: game_state} = state, new_target_pos) do
    if game_state.action_state == :combat_moving and game_state.combat_target_id do
      # Check if target moved significantly (more than 3 cells)
      if should_recalculate_path?(game_state.last_target_position, new_target_pos) do
        # Recalculate path to new target position
        recalculate_combat_path(state, new_target_pos)
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @doc """
  Cancels any active combat intent and transitions to idle.
  """
  @spec cancel_combat_intent(map()) :: map()
  def cancel_combat_intent(%{game_state: game_state} = state) do
    updated_game_state = PlayerState.clear_combat_intent(game_state)
    {:ok, transitioned_state} = PlayerState.transition_to(updated_game_state, :idle)
    %{state | game_state: transitioned_state}
  end

  @doc """
  Calculates the optimal position to attack from, considering weapon range.
  """
  @spec get_optimal_attack_position({integer(), integer()}, {integer(), integer()}, integer()) ::
          {integer(), integer()}
  def get_optimal_attack_position({attacker_x, attacker_y}, {target_x, target_y}, weapon_range) do
    distance = Geometry.chebyshev_distance(attacker_x, attacker_y, target_x, target_y)

    if distance <= weapon_range do
      # Already in range
      {attacker_x, attacker_y}
    else
      # Calculate a position that's within weapon range of the target
      # We want to move to a position that's at most weapon_range cells from target

      # Calculate direction vector
      dx = target_x - attacker_x
      dy = target_y - attacker_y

      # For Chebyshev distance, we need to handle each axis independently
      # The optimal position should be at most weapon_range cells from target

      # Calculate how much we need to move
      max_component = max(abs(dx), abs(dy))

      if max_component > 0 do
        # We need to be (max_component - weapon_range) cells closer
        cells_to_move = max_component - weapon_range
        scale = cells_to_move / max_component

        # Move towards target by the calculated amount
        optimal_x = attacker_x + round(dx * scale)
        optimal_y = attacker_y + round(dy * scale)
        {optimal_x, optimal_y}
      else
        {attacker_x, attacker_y}
      end
    end
  end

  # Private functions

  defp check_attack_range(state, target_id) do
    weapon_type = get_weapon_type(state.game_state.stats)
    attack_range = WeaponTypes.get_attack_range(weapon_type)

    Logger.debug("Checking attack range - weapon: #{weapon_type}, range: #{attack_range}")

    case get_target_position(target_id) do
      {:ok, {target_x, target_y}} ->
        player_x = state.game_state.x
        player_y = state.game_state.y

        distance =
          Geometry.chebyshev_distance(
            player_x,
            player_y,
            target_x,
            target_y
          )

        Logger.debug(
          "Player at (#{player_x}, #{player_y}), Target at (#{target_x}, #{target_y}), Distance: #{distance}"
        )

        if distance <= attack_range do
          Logger.debug("✓ Target IS in range (#{distance} <= #{attack_range})")
          {:in_range, distance}
        else
          Logger.debug("✗ Target NOT in range (#{distance} > #{attack_range})")
          {:out_of_range, {target_x, target_y}}
        end

      {:error, reason} ->
        Logger.debug("Failed to get target position: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_target_position(target_id) do
    # Try to get position from spatial index (could be player or mob)
    case SpatialIndex.get_unit_position(:player, target_id) do
      {:ok, {x, y, _map}} ->
        {:ok, {x, y}}

      {:error, :not_found} ->
        # Try mob
        case SpatialIndex.get_unit_position(:mob, target_id) do
          {:ok, {x, y, _map}} ->
            {:ok, {x, y}}

          {:error, :not_found} ->
            {:error, :target_not_found}
        end
    end
  end

  defp execute_immediate_attack(state, target_id) do
    Logger.debug("execute_immediate_attack called for target #{target_id}")

    case PlayerState.transition_to(state.game_state, :attacking) do
      {:ok, transitioned_state} ->
        Logger.debug("Successfully transitioned to attacking state")
        handle_attack_execution(state, target_id, transitioned_state)

      {:error, :invalid_transition} ->
        Logger.warning(
          "Cannot transition to attacking state from #{state.game_state.action_state} (current state)"
        )

        Logger.debug("Full game state: #{inspect(state.game_state, limit: :infinity)}")
        {:noreply, state}
    end
  end

  defp handle_attack_execution(state, target_id, transitioned_state) do
    Logger.debug("Calling Combat.execute_attack with target_id=#{target_id}")

    case Combat.execute_attack(transitioned_state.stats, transitioned_state, target_id) do
      :ok ->
        handle_successful_attack(state, transitioned_state)

      {:error, :target_out_of_range} ->
        handle_target_out_of_range(state, target_id, transitioned_state)

      {:error, reason} ->
        handle_attack_failure(state, transitioned_state, reason)
    end
  end

  defp handle_successful_attack(state, transitioned_state) do
    Logger.info("Attack executed successfully")
    current_timestamp = AttackSpeed.current_timestamp()
    Logger.debug("Updating attack timestamp to #{current_timestamp}")
    Logger.debug("Combat action type: #{inspect(state.game_state.combat_action_type)}")

    game_state = determine_post_attack_state(state, transitioned_state, current_timestamp)
    {:noreply, %{state | game_state: game_state}}
  end

  defp determine_post_attack_state(state, transitioned_state, current_timestamp) do
    if state.game_state.combat_action_type == 7 do
      Logger.debug("Continuous attack mode - staying in attacking state for chase mechanics")
      %{transitioned_state | last_attack_timestamp: current_timestamp}
    else
      Logger.debug("Single attack mode - returning to idle")
      {:ok, idle_state} = PlayerState.transition_to(transitioned_state, :idle)
      %{idle_state | last_attack_timestamp: current_timestamp}
    end
  end

  defp handle_target_out_of_range(state, target_id, transitioned_state) do
    Logger.info("Target moved out of range during attack - initiating chase")

    case get_target_position(target_id) do
      {:ok, {new_x, new_y}} ->
        Logger.debug("Target moved to (#{new_x}, #{new_y}) - chasing")
        updated_state = %{state | game_state: transitioned_state}

        initiate_combat_movement(
          updated_state,
          target_id,
          state.game_state.combat_action_type,
          {new_x, new_y}
        )

      {:error, _reason} ->
        Logger.warning("Target no longer exists - clearing combat")
        return_to_idle_from_combat(state, transitioned_state)
    end
  end

  defp handle_attack_failure(state, transitioned_state, reason) do
    Logger.warning("Attack failed with reason: #{inspect(reason)}")
    {:ok, idle_state} = PlayerState.transition_to(transitioned_state, :idle)
    {:noreply, %{state | game_state: idle_state}}
  end

  defp return_to_idle_from_combat(state, transitioned_state) do
    updated_game_state = PlayerState.clear_combat_intent(transitioned_state)
    {:ok, idle_state} = PlayerState.transition_to(updated_game_state, :idle)
    {:noreply, %{state | game_state: idle_state}}
  end

  defp initiate_combat_movement(state, target_id, action_type, {target_x, target_y}) do
    Logger.info("=== INITIATING COMBAT MOVEMENT ===")

    with {:ok, combat_context} <- prepare_combat_context(state, {target_x, target_y}),
         {:ok, map_data} <- MapCache.get(state.game_state.map_name) do
      handle_pathfinding_to_target(state, target_id, action_type, combat_context, map_data)
    else
      {:error, reason} ->
        Logger.error("Failed to initiate combat movement: #{reason}")
        {:noreply, state}
    end
  end

  defp prepare_combat_context(state, {target_x, target_y}) do
    weapon_type = get_weapon_type(state.game_state.stats)
    attack_range = WeaponTypes.get_attack_range(weapon_type)
    current_pos = {state.game_state.x, state.game_state.y}
    optimal_pos = get_optimal_attack_position(current_pos, {target_x, target_y}, attack_range)

    Logger.debug("Weapon: #{weapon_type}, Range: #{attack_range}")

    Logger.debug(
      "Current pos: #{inspect(current_pos)}, Target pos: (#{target_x}, #{target_y}), Optimal pos: #{inspect(optimal_pos)}"
    )

    {:ok,
     %{
       current_pos: current_pos,
       target_pos: {target_x, target_y},
       optimal_pos: optimal_pos,
       attack_range: attack_range
     }}
  end

  defp handle_pathfinding_to_target(state, target_id, action_type, context, map_data) do
    case Pathfinding.find_path(map_data, context.current_pos, context.optimal_pos) do
      {:ok, [_ | _] = _path} ->
        move_to_optimal_position(state, target_id, action_type, context)

      {:ok, []} ->
        handle_already_at_optimal_position(state, target_id, action_type, context, map_data)

      {:error, reason} ->
        Logger.warning("No path to target for combat: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp move_to_optimal_position(state, target_id, action_type, context) do
    game_state =
      PlayerState.set_combat_intent(
        state.game_state,
        target_id,
        action_type,
        context.target_pos
      )

    case PlayerState.transition_to(game_state, :combat_moving) do
      {:ok, transitioned_state} ->
        Logger.debug("Transitioned to combat_moving state")
        updated_state = %{state | game_state: transitioned_state}
        Logger.debug("Starting movement to optimal position: #{inspect(context.optimal_pos)}")

        MovementHandler.handle_request_move(
          updated_state,
          elem(context.optimal_pos, 0),
          elem(context.optimal_pos, 1),
          combat_initiated: true
        )

      {:error, :invalid_transition} ->
        Logger.error("FAILED to transition to combat_moving from #{game_state.action_state}")
        {:noreply, state}
    end
  end

  defp handle_already_at_optimal_position(state, target_id, action_type, context, map_data) do
    case check_attack_range(state, target_id) do
      {:in_range, _} ->
        Logger.debug("At optimal position and in range, executing attack")
        execute_immediate_attack(state, target_id)

      {:out_of_range, _target_pos} ->
        Logger.debug("At calculated position but still out of range, adjusting")
        handle_position_adjustment(state, target_id, action_type, context, map_data)

      {:error, reason} ->
        Logger.warning("Target check failed: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp handle_position_adjustment(state, target_id, action_type, context, map_data) do
    {target_x, target_y} = context.target_pos
    {current_x, current_y} = context.current_pos

    adjusted_pos = calculate_adjusted_position({current_x, current_y}, {target_x, target_y})

    case Pathfinding.find_path(map_data, context.current_pos, adjusted_pos) do
      {:ok, [_ | _] = _short_path} ->
        move_to_adjusted_position(state, target_id, action_type, context, adjusted_pos)

      _ ->
        Logger.warning("Cannot adjust position, attempting attack anyway")
        execute_immediate_attack(state, target_id)
    end
  end

  defp calculate_adjusted_position({current_x, current_y}, {target_x, target_y}) do
    dx = if target_x > current_x, do: 1, else: if(target_x < current_x, do: -1, else: 0)
    dy = if target_y > current_y, do: 1, else: if(target_y < current_y, do: -1, else: 0)
    {current_x + dx, current_y + dy}
  end

  defp move_to_adjusted_position(state, target_id, action_type, context, {adjusted_x, adjusted_y}) do
    game_state =
      PlayerState.set_combat_intent(
        state.game_state,
        target_id,
        action_type,
        context.target_pos
      )

    case PlayerState.transition_to(game_state, :combat_moving) do
      {:ok, transitioned_state} ->
        updated_state = %{state | game_state: transitioned_state}

        MovementHandler.handle_request_move(updated_state, adjusted_x, adjusted_y,
          combat_initiated: true
        )

      {:error, :invalid_transition} ->
        Logger.warning("Cannot transition to combat_moving for adjustment")
        {:noreply, state}
    end
  end

  defp should_recalculate_path?(nil, _), do: true

  defp should_recalculate_path?({old_x, old_y}, {new_x, new_y}) do
    # Recalculate if target moved more than 3 cells
    Geometry.chebyshev_distance(old_x, old_y, new_x, new_y) > 3
  end

  defp recalculate_combat_path(state, {new_target_x, new_target_y}) do
    weapon_type = get_weapon_type(state.game_state.stats)
    attack_range = WeaponTypes.get_attack_range(weapon_type)

    # Calculate new optimal position
    optimal_pos =
      get_optimal_attack_position(
        {state.game_state.x, state.game_state.y},
        {new_target_x, new_target_y},
        attack_range
      )

    # Update target position and recalculate path
    game_state = %{state.game_state | last_target_position: {new_target_x, new_target_y}}
    updated_state = %{state | game_state: game_state}

    # Stop current movement and start new path
    MovementHandler.handle_force_stop_movement(updated_state)
    # Extract state from {:noreply, state}
    |> elem(1)
    |> then(fn stopped_state ->
      MovementHandler.handle_request_move(
        stopped_state,
        elem(optimal_pos, 0),
        elem(optimal_pos, 1),
        combat_initiated: true
      )
    end)
  end

  defp get_weapon_type(_stats) do
    # TODO: Get actual weapon type from equipment
    # For now, return same as Combat.build_attacker_stats to ensure consistency
    :one_handed_sword
  end
end
