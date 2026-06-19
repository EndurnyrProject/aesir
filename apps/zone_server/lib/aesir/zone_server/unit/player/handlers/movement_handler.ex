defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler do
  @moduledoc """
  Handles player movement operations including pathfinding, movement ticks, and broadcasting.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveentry
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveStop
  alias Aesir.ZoneServer.Packets.ZcNotifyNewentry
  alias Aesir.ZoneServer.Packets.ZcNotifyPlayermove
  alias Aesir.ZoneServer.Packets.ZcNotifyVanish
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Handles movement tick processing for a walking player.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:noreply, updated_state} - Updated state with new position/walking status
  """
  def handle_movement_tick(state)

  def handle_movement_tick(%{game_state: %{movement_state: :standing}} = state) do
    {:noreply, state}
  end

  def handle_movement_tick(%{game_state: %{movement_state: :moving, walk_path: []}} = state) do
    game_state = PlayerState.stop_walking(state.game_state)
    updated_state = %{state | game_state: game_state}

    # Send message to self for movement completion handling
    # This allows PlayerSession to orchestrate based on state
    send(self(), :movement_completed)

    {:noreply, updated_state}
  end

  def handle_movement_tick(%{game_state: game_state} = state)
      when game_state.movement_state == :moving do
    case game_state.walk_path do
      [{next_x, next_y} | remaining_path] ->
        # Calculate movement cost for this step
        move_cost =
          MovementEngine.get_movement_cost({game_state.x, game_state.y}, {next_x, next_y})

        # Calculate timer interval based on movement cost
        # Diagonal movement takes 1.414x longer
        interval = round(game_state.walk_speed * move_cost)

        # Update spatial index
        SpatialIndex.update_position(game_state.character_id, next_x, next_y, game_state.map_name)

        # Update game state with new position
        updated_game_state =
          game_state
          |> PlayerState.update_position(next_x, next_y)
          |> Map.put(:walk_path, remaining_path)

        # Sync the registry before visibility so players we enter view of read
        # our current position when building our spawn packet.
        UnitRegistry.update_unit_state(
          :player,
          updated_game_state.character_id,
          updated_game_state
        )

        # Handle visibility updates
        updated_game_state = handle_visibility_update(updated_game_state)

        # Schedule next movement tick with appropriate interval
        if remaining_path != [] do
          Process.send_after(self(), :movement_tick, interval)
          {:noreply, %{state | game_state: updated_game_state}}
        else
          # Path completed, stop movement
          game_state = PlayerState.stop_walking(updated_game_state)
          # Send completion message for PlayerSession to handle
          send(self(), :movement_completed)
          {:noreply, %{state | game_state: game_state}}
        end
    end
  end

  @doc """
  Handles a movement request from the client.

  ## Parameters
    - state: The player session state
    - dest_x: Destination X coordinate
    - dest_y: Destination Y coordinate
    
  ## Returns
    - {:noreply, updated_state} - Updated state with movement path or error handling
  """
  def handle_request_move(
        %{game_state: game_state, connection_pid: connection_pid} = state,
        dest_x,
        dest_y,
        opts \\ []
      ) do
    with {:ok, map_data} <- MapCache.get(game_state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.find_path(
             map_data,
             {game_state.x, game_state.y},
             {dest_x, dest_y}
           ) do
      # Simplify path to reduce network traffic
      simplified_path = Pathfinding.simplify_path(path)

      # Check if we're in combat_moving state and this is a player-initiated move
      # Only clear combat intent if this is NOT a combat-initiated movement
      is_combat_initiated = Keyword.get(opts, :combat_initiated, false)

      game_state = maybe_clear_combat_intent(game_state, is_combat_initiated)

      # Update game state with new path
      game_state = PlayerState.set_path(game_state, simplified_path)

      # Send movement confirmation to the client
      walk_start_time = System.monotonic_time(:millisecond)

      packet = %ZcNotifyPlayermove{
        walk_start_time: walk_start_time,
        src_x: game_state.x,
        src_y: game_state.y,
        dst_x: dest_x,
        dst_y: dest_y
      }

      send(connection_pid, {:send_packet, packet})

      # Broadcast movement to nearby players
      broadcast_movement_to_nearby(game_state, dest_x, dest_y)

      # Schedule first movement tick immediately to start movement
      Process.send_after(self(), :movement_tick, 0)

      {:noreply, %{state | game_state: game_state}}
    else
      {:ok, []} ->
        # Already at destination
        {:noreply, state}

      {:error, reason} ->
        # No path found or map not loaded
        Logger.error("Movement failed for player #{game_state.character_id}: #{inspect(reason)}")

        packet = %ZcNotifyMoveStop{
          account_id: game_state.account_id,
          x: game_state.x,
          y: game_state.y
        }

        send(connection_pid, {:send_packet, packet})

        {:noreply, state}
    end
  end

  defp maybe_clear_combat_intent(%{action_state: :combat_moving} = game_state, false) do
    Logger.debug("Player manually moving while in combat, clearing combat intent")

    game_state
    |> PlayerState.clear_combat_intent()
    |> PlayerState.transition_to(:moving)
    |> case do
      {:ok, transitioned} -> transitioned
      _ -> game_state
    end
  end

  defp maybe_clear_combat_intent(game_state, _is_combat_initiated), do: game_state

  @doc """
  Forces a player to stop moving immediately.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:noreply, updated_state} - Updated state with stopped movement
  """
  def handle_force_stop_movement(
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    if game_state.movement_state == :moving do
      game_state = PlayerState.stop_walking(game_state)

      packet = %ZcNotifyMoveStop{
        account_id: game_state.account_id,
        x: game_state.x,
        y: game_state.y
      }

      send(connection_pid, {:send_packet, packet})

      broadcast_stop_to_nearby(game_state, packet)

      {:noreply, %{state | game_state: game_state}}
    else
      {:noreply, state}
    end
  end

  defp broadcast_stop_to_nearby(game_state, packet) do
    Broadcast.to_in_range(
      game_state.map_name,
      game_state.x,
      game_state.y,
      game_state.view_range,
      packet,
      exclude_id: game_state.character_id
    )
  end

  defp broadcast_movement_to_nearby(game_state, dest_x, dest_y) do
    # Only broadcast to players who can see us (using visibility ETS)
    packet = build_movement_packet(game_state, dest_x, dest_y)

    game_state.character_id
    |> SpatialIndex.get_visible_players()
    |> Broadcast.to_players(packet, exclude_id: game_state.character_id)
  end

  defp build_movement_packet(game_state, dest_x, dest_y) do
    %ZcNotifyMoveentry{
      object_type: ObjectType.pc(),
      aid: game_state.account_id,
      gid: game_state.character_id,
      speed: game_state.walk_speed,
      body_state: 0,
      health_state: 0,
      effect_state: 0,
      job: game_state.stats.progression.job_id,
      head: game_state.hair,
      weapon: PlayerStats.weapon_view(game_state.stats.equipment),
      shield: PlayerStats.shield_view(game_state.stats.equipment),
      accessory: 0,
      move_start_time: System.monotonic_time(:millisecond),
      accessory2: 0,
      accessory3: 0,
      src_x: game_state.x,
      src_y: game_state.y,
      dst_x: dest_x,
      dst_y: dest_y,
      head_palette: game_state.hair_color,
      body_palette: game_state.clothes_color,
      head_dir: 0,
      robe: game_state.robe,
      guild_id: 0,
      guild_emblem_ver: 0,
      honor: 0,
      virtue: 0,
      is_pk_mode_on: 0,
      sex: sex_to_int(game_state.sex)
    }
  end

  @doc """
  Updates visibility for nearby players when a player's position changes.
  This function is public so it can be used by PlayerSession for non-movement visibility updates.
  """
  def handle_visibility_update(game_state) do
    players_in_range =
      SpatialIndex.get_players_in_range(
        game_state.map_name,
        game_state.x,
        game_state.y,
        game_state.view_range
      )

    new_visible = MapSet.new(players_in_range)
    old_visible = game_state.visible_players

    # Find who entered and left view
    now_visible = MapSet.difference(new_visible, old_visible)
    now_hidden = MapSet.difference(old_visible, new_visible)

    # Send spawn packets for newly visible players
    Enum.each(now_visible, fn other_id ->
      if other_id != game_state.character_id do
        # Update visibility ETS
        SpatialIndex.update_visibility(game_state.character_id, other_id, true)

        # Send spawn packet to us about them
        send_spawn_packet_about(game_state.character_id, other_id)

        # Send spawn packet to them about us
        send_spawn_packet_about(other_id, game_state.character_id)
      end
    end)

    # Send despawn packets for now hidden players
    Enum.each(now_hidden, fn other_id ->
      if other_id != game_state.character_id do
        # Update visibility ETS
        SpatialIndex.update_visibility(game_state.character_id, other_id, false)

        # Send vanish packet to us
        send_vanish_packet_to(game_state.character_id, other_id)

        # Send vanish packet to them
        send_vanish_packet_to(other_id, game_state.character_id)
      end
    end)

    # Handle mob visibility - use consistent map naming
    # Both players and mobs should use the same map name format
    mobs_in_range =
      SpatialIndex.get_units_in_range(
        :mob,
        game_state.map_name,
        game_state.x,
        game_state.y,
        game_state.view_range
      )

    new_visible_mobs = MapSet.new(mobs_in_range)
    old_visible_mobs = game_state.visible_mobs

    # Find which mobs entered and left view
    now_visible_mobs = MapSet.difference(new_visible_mobs, old_visible_mobs)
    now_hidden_mobs = MapSet.difference(old_visible_mobs, new_visible_mobs)

    # Send spawn packets for newly visible mobs
    Enum.each(now_visible_mobs, fn mob_id ->
      send_mob_spawn_packet_to(game_state.character_id, mob_id)
    end)

    # Send despawn packets for now hidden mobs
    Enum.each(now_hidden_mobs, fn mob_id ->
      send_mob_vanish_packet_to(game_state.character_id, mob_id)
    end)

    # Update game state with new visibility info
    # Keep last_visibility_cell for potential optimization later
    current_cell = {div(game_state.x, 8), div(game_state.y, 8)}

    %{
      game_state
      | visible_players: new_visible,
        visible_mobs: new_visible_mobs,
        last_visibility_cell: current_cell
    }
  end

  defp send_spawn_packet_about(to_char_id, about_char_id) do
    # Get the player session for the target
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, pid} ->
        GenServer.cast(pid, {:player_entered_view, about_char_id})

      {:error, :not_found} ->
        :ok
    end
  end

  defp send_vanish_packet_to(to_char_id, about_char_id) do
    # Get the player session for the target and the account_id of the vanishing player
    with {:ok, to_pid} <- UnitRegistry.get_player_pid(to_char_id),
         {:ok, {_about_pid, about_account_id}} <-
           UnitRegistry.get_player_with_account(about_char_id) do
      GenServer.cast(to_pid, {:player_left_view, about_char_id, about_account_id})
    else
      _ -> :ok
    end
  end

  defp send_mob_spawn_packet_to(to_char_id, mob_id) do
    # Get the player session and mob data
    with {:ok, to_pid} <- UnitRegistry.get_player_pid(to_char_id),
         {:ok, {_module, mob_state, _pid}} <- UnitRegistry.get_unit(:mob, mob_id) do
      # Create mob spawn packet
      mob_packet = %ZcNotifyNewentry{
        object_type: ObjectType.mob(),
        aid: mob_state.instance_id,
        gid: mob_state.instance_id,
        speed: mob_state.walk_speed,
        body_state: 0,
        health_state: if(mob_state.is_dead, do: 1, else: 0),
        effect_state: 0,
        # Mob sprite ID
        job: mob_state.mob_id,
        head: 0,
        weapon: 0,
        shield: 0,
        accessory: 0,
        accessory2: 0,
        accessory3: 0,
        head_palette: 0,
        body_palette: 0,
        head_dir: 0,
        robe: 0,
        guild_id: 0,
        guild_emblem_ver: 0,
        honor: 0,
        virtue: 0,
        is_pk_mode_on: 0,
        sex: 0,
        x: mob_state.x,
        y: mob_state.y,
        dir: mob_state.dir,
        x_size: 0,
        y_size: 0,
        clevel: mob_state.mob_data.level,
        font: 0,
        max_hp: mob_state.max_hp,
        hp: mob_state.hp,
        is_boss: if(MobState.is_boss?(mob_state), do: 1, else: 0),
        body: 0,
        name: mob_state.mob_data.name
      }

      GenServer.cast(to_pid, {:send_packet, mob_packet})
    else
      _ -> :ok
    end
  end

  defp send_mob_vanish_packet_to(to_char_id, mob_id) do
    # Get the player session
    case UnitRegistry.get_player_pid(to_char_id) do
      {:ok, to_pid} ->
        vanish_packet = %ZcNotifyVanish{
          gid: mob_id,
          # 0 = died, 1 = logged out, 2 = teleported
          type: 0
        }

        GenServer.cast(to_pid, {:send_packet, vanish_packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp sex_to_int("M"), do: 1
  defp sex_to_int("F"), do: 0
  defp sex_to_int(_), do: 1
end
