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
    cells_per_ms = 1.0 / game_state.walk_speed
    total_movement_budget = elapsed * cells_per_ms

    # Calculate NEW movement since last tick (subtract what we already consumed)
    new_movement_budget = total_movement_budget - game_state.path_progress

    # Consume path based on NEW movement budget
    {new_x, new_y, remaining_path, consumed} =
      consume_movement_path_with_cost(
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

  defp consume_movement_path_with_cost(x, y, path, budget) do
    do_consume_path(x, y, path, budget, 0)
  end

  defp do_consume_path(x, y, [], _budget, consumed), do: {x, y, [], consumed}
  defp do_consume_path(x, y, path, budget, consumed) when budget <= 0, do: {x, y, path, consumed}

  defp do_consume_path(x, y, [{next_x, next_y} | rest], budget, consumed) do
    move_cost =
      if abs(next_x - x) == 1 and abs(next_y - y) == 1 do
        # Diagonal movement (√2)
        1.414
      else
        # Straight movement
        1.0
      end

    if move_cost <= budget do
      do_consume_path(next_x, next_y, rest, budget - move_cost, consumed + move_cost)
    else
      {x, y, [{next_x, next_y} | rest], consumed}
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

    # Update game state with new visibility info
    # Keep last_visibility_cell for potential optimization later
    current_cell = {div(game_state.x, 8), div(game_state.y, 8)}
    %{game_state | visible_players: new_visible, last_visibility_cell: current_cell}
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

  defp sex_to_int("M"), do: 1
  defp sex_to_int("F"), do: 0
  defp sex_to_int(_), do: 1
end
