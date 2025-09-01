defmodule Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler do
  @moduledoc """
  Handles player movement operations including pathfinding, movement ticks, and broadcasting.
  Extracted from PlayerSession to improve modularity and maintainability.
  """

  require Logger

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveentry
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveStop
  alias Aesir.ZoneServer.Packets.ZcNotifyPlayermove
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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

  def handle_movement_tick(%{game_state: %{is_walking: false}} = state) do
    {:noreply, state}
  end

  def handle_movement_tick(%{game_state: %{is_walking: true, walk_path: []}} = state) do
    game_state = PlayerState.stop_walking(state.game_state)
    {:noreply, %{state | game_state: game_state}}
  end

  def handle_movement_tick(%{character: character, game_state: game_state} = state)
      when game_state.is_walking do
    # Calculate how far we should have moved since start
    elapsed = System.system_time(:millisecond) - game_state.walk_start_time

    total_movement_budget =
      MovementEngine.calculate_movement_budget(elapsed, game_state.walk_speed)

    # Calculate NEW movement since last tick (subtract what we already consumed)
    new_movement_budget = total_movement_budget - game_state.path_progress

    # Consume path based on NEW movement budget
    {new_x, new_y, remaining_path, consumed} =
      MovementEngine.consume_path_with_budget(
        game_state.x,
        game_state.y,
        game_state.walk_path,
        new_movement_budget
      )

    # Update game state with new position and progress
    game_state =
      if new_x != game_state.x or new_y != game_state.y do
        SpatialIndex.update_position(character.id, new_x, new_y, game_state.map_name)

        updated_state =
          game_state
          |> PlayerState.update_position(new_x, new_y)
          |> Map.put(:walk_path, remaining_path)
          |> Map.put(:path_progress, game_state.path_progress + consumed)

        handle_visibility_update(character, updated_state)
      else
        game_state
        |> Map.put(:walk_path, remaining_path)
        |> Map.put(:path_progress, game_state.path_progress + consumed)
      end

    game_state =
      if remaining_path == [] do
        PlayerState.stop_walking(game_state)
      else
        Process.send_after(self(), :movement_tick, 100)
        game_state
      end

    {:noreply, %{state | game_state: game_state}}
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
        %{character: character, game_state: game_state, connection_pid: connection_pid} = state,
        dest_x,
        dest_y
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

      # Start movement
      walk_start_time = System.system_time(:millisecond)

      # Update game state with new path
      game_state =
        game_state
        |> PlayerState.set_path(simplified_path)
        |> Map.put(:walk_start_time, walk_start_time)

      # Send movement confirmation to the client
      packet = %ZcNotifyPlayermove{
        walk_start_time: walk_start_time,
        src_x: game_state.x,
        src_y: game_state.y,
        dst_x: dest_x,
        dst_y: dest_y
      }

      send(connection_pid, {:send_packet, packet})

      # Broadcast movement to nearby players
      broadcast_movement_to_nearby(character, game_state, dest_x, dest_y)

      Process.send_after(self(), :movement_tick, 100)

      {:noreply, %{state | game_state: game_state}}
    else
      {:ok, []} ->
        # Already at destination
        {:noreply, state}

      {:error, reason} ->
        # No path found or map not loaded
        Logger.error("Movement failed for player #{character.id}: #{inspect(reason)}")

        packet = %ZcNotifyMoveStop{
          account_id: character.account_id,
          x: game_state.x,
          y: game_state.y
        }

        send(connection_pid, {:send_packet, packet})

        {:noreply, state}
    end
  end

  @doc """
  Forces a player to stop moving immediately.

  ## Parameters
    - state: The player session state
    
  ## Returns
    - {:noreply, updated_state} - Updated state with stopped movement
  """
  def handle_force_stop_movement(
        %{character: character, game_state: game_state, connection_pid: connection_pid} = state
      ) do
    if game_state.is_walking do
      game_state = PlayerState.stop_walking(game_state)

      packet = %ZcNotifyMoveStop{
        account_id: character.account_id,
        x: game_state.x,
        y: game_state.y
      }

      send(connection_pid, {:send_packet, packet})

      broadcast_stop_to_nearby(character, game_state, packet)

      {:noreply, %{state | game_state: game_state}}
    else
      {:noreply, state}
    end
  end

  defp broadcast_stop_to_nearby(character, game_state, packet) do
    nearby_players =
      SpatialIndex.get_players_in_range(
        game_state.map_name,
        game_state.x,
        game_state.y,
        game_state.view_range
      )

    nearby_players
    |> Enum.filter(&(&1 != character.id))
    |> Enum.each(&send_packet_to_player(&1, packet))
  end

  defp send_packet_to_player(char_id, packet) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} ->
        GenServer.cast(pid, {:send_packet, packet})

      {:error, :not_found} ->
        :ok
    end
  end

  defp broadcast_movement_to_nearby(character, game_state, dest_x, dest_y) do
    # Only broadcast to players who can see us (using visibility ETS)
    visible_players = SpatialIndex.get_visible_players(character.id)

    # Build movement packet for observers
    packet = build_movement_packet(character, game_state, dest_x, dest_y)

    visible_players
    |> Enum.filter(&(&1 != character.id))
    |> Enum.each(&send_packet_to_player(&1, packet))
  end

  defp build_movement_packet(character, game_state, dest_x, dest_y) do
    %ZcNotifyMoveentry{
      aid: character.account_id,
      gid: character.id,
      speed: game_state.walk_speed,
      body_state: 0,
      health_state: 0,
      effect_state: 0,
      job: character.class,
      head: character.head_top,
      weapon: character.weapon || 0,
      shield: character.shield || 0,
      accessory: character.head_bottom || 0,
      move_start_time: System.system_time(:millisecond),
      accessory2: character.head_mid || 0,
      accessory3: 0,
      src_x: game_state.x,
      src_y: game_state.y,
      dst_x: dest_x,
      dst_y: dest_y,
      head_palette: character.hair_color,
      body_palette: character.clothes_color,
      head_dir: 0,
      robe: character.robe || 0,
      guild_id: 0,
      guild_emblem_ver: 0,
      honor: 0,
      virtue: 0,
      is_pk_mode_on: 0,
      sex: sex_to_int(character.sex)
    }
  end

  @doc """
  Updates visibility for nearby players when a player's position changes.
  This function is public so it can be used by PlayerSession for non-movement visibility updates.
  """
  def handle_visibility_update(character, game_state) do
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
      if other_id != character.id do
        # Update visibility ETS
        SpatialIndex.update_visibility(character.id, other_id, true)

        # Send spawn packet to us about them
        send_spawn_packet_about(character.id, other_id)

        # Send spawn packet to them about us
        send_spawn_packet_about(other_id, character.id)
      end
    end)

    # Send despawn packets for now hidden players
    Enum.each(now_hidden, fn other_id ->
      if other_id != character.id do
        # Update visibility ETS
        SpatialIndex.update_visibility(character.id, other_id, false)

        # Send vanish packet to us
        send_vanish_packet_to(character.id, other_id)

        # Send vanish packet to them
        send_vanish_packet_to(other_id, character.id)
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
      send_mob_spawn_packet_to(character.id, mob_id)
    end)

    # Send despawn packets for now hidden mobs
    Enum.each(now_hidden_mobs, fn mob_id ->
      send_mob_vanish_packet_to(character.id, mob_id)
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
      mob_packet = %Aesir.ZoneServer.Packets.ZcNotifyNewentry{
        object_type: Aesir.ZoneServer.Constants.ObjectType.mob(),
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
        is_boss: if(Aesir.ZoneServer.Unit.Mob.MobState.is_boss?(mob_state), do: 1, else: 0),
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
        vanish_packet = %Aesir.ZoneServer.Packets.ZcNotifyVanish{
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
