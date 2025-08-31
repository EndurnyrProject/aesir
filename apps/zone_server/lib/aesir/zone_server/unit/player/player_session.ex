defmodule Aesir.ZoneServer.Unit.Player.PlayerSession do
  @moduledoc """
  GenServer managing a single player's session.
  Each player gets their own process for fault isolation and concurrency.
  """

  use GenServer

  import Aesir.ZoneServer.EtsTable

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Packets.ZcEquipitemList
  alias Aesir.ZoneServer.Packets.ZcLongparChange
  alias Aesir.ZoneServer.Packets.ZcNormalItemlist
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveentry
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveStop
  alias Aesir.ZoneServer.Packets.ZcNotifyNewentry
  alias Aesir.ZoneServer.Packets.ZcNotifyPlayermove
  alias Aesir.ZoneServer.Packets.ZcNotifyStandentry
  alias Aesir.ZoneServer.Packets.ZcNotifyVanish
  alias Aesir.ZoneServer.Packets.ZcParChange
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Starts a player session linked to a connection process.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Handles a movement request from the client.
  """
  def request_move(pid, dest_x, dest_y) do
    GenServer.cast(pid, {:request_move, dest_x, dest_y})
  end

  @doc """
  Sends a packet to this player.
  """
  def send_packet(pid, packet) do
    GenServer.cast(pid, {:send_packet, packet})
  end

  @doc """
  Gets the current player state.
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Handles player disconnect.
  """
  def disconnect(pid) do
    GenServer.stop(pid, :normal)
  end

  @doc """
  Forces a player to stop moving (e.g., due to skill, stun, etc.)
  Sends ZC_NOTIFY_MOVE_STOP to fix client position.
  """
  def force_stop_movement(pid) do
    GenServer.cast(pid, :force_stop_movement)
  end

  @doc """
  Sends a status update to this player.
  Automatically chooses between ZC_PAR_CHANGE and ZC_LONGPAR_CHANGE based on value size.
  """
  def send_status_update(pid, param_id, value) do
    GenServer.cast(pid, {:send_status_update, param_id, value})
  end

  @doc """
  Sends multiple status updates to this player efficiently.
  """
  def send_status_updates(pid, status_map) when is_map(status_map) do
    GenServer.cast(pid, {:send_status_updates, status_map})
  end

  @doc """
  Updates a base stat and recalculates derived stats.
  """
  def update_base_stat(pid, stat_name, new_value)
      when stat_name in [:str, :agi, :vit, :int, :dex, :luk] do
    GenServer.call(pid, {:update_base_stat, stat_name, new_value})
  end

  @doc """
  Recalculates all stats and synchronizes with client.

  ## Parameters
  - pid: The process ID of the player session
  - sync: Whether to wait for the recalculation to complete (defaults to true)

  When sync is true, uses call which waits for the stats to be recalculated.
  When sync is false, uses cast which doesn't wait (more efficient for background updates).
  """
  def recalculate_stats(pid, sync \\ true)

  def recalculate_stats(pid, true) do
    # Synchronous version using call
    GenServer.call(pid, :recalculate_stats)
  end

  def recalculate_stats(pid, false) do
    # Asynchronous version using cast
    GenServer.cast(pid, :recalculate_stats)
    :ok
  end

  @doc """
  Gets the current Stats struct.
  """
  def get_current_stats(pid) do
    GenServer.call(pid, :get_current_stats)
  end

  @doc """
  Applies a status effect to the player.
  Delegates to the StatusEffect.Interpreter and triggers stats recalculation.
  """
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def apply_status(
        pid,
        status_id,
        val1 \\ 0,
        val2 \\ 0,
        val3 \\ 0,
        val4 \\ 0,
        tick \\ 0,
        flag \\ 0,
        caster_id \\ nil
      ) do
    GenServer.call(pid, {:apply_status, status_id, val1, val2, val3, val4, tick, flag, caster_id})
  end

  @doc """
  Removes a status effect from the player.
  Delegates to the StatusEffect.Interpreter and triggers stats recalculation.
  """
  def remove_status(pid, status_id) do
    GenServer.call(pid, {:remove_status, status_id})
  end

  @doc """
  Gets all active status effects for the player.
  """
  def get_active_statuses(pid) do
    GenServer.call(pid, :get_active_statuses)
  end

  @doc """
  Checks if a player has a specific status effect.
  """
  def has_status?(pid, status_id) do
    GenServer.call(pid, {:has_status, status_id})
  end

  @impl true
  def init(args) do
    character = args[:character]
    connection_pid = args[:connection_pid]
    game_state = PlayerState.new(character)

    # Load character's inventory
    case Inventory.load_inventory(character.id) do
      {:ok, inventory_items} ->
        updated_game_state =
          game_state
          |> PlayerState.set_inventory(inventory_items)
          |> PlayerState.set_process_pid(self())

        state = %{
          character: character,
          game_state: updated_game_state,
          connection_pid: connection_pid
        }

        # Register with both ETS and UnitRegistry
        register_player(character.id, character.account_id)
        UnitRegistry.register_unit(:player, character.id, PlayerState, updated_game_state, self())

        send(self(), :spawn_player)

        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to load inventory for character #{character.id}: #{inspect(reason)}")
        {:stop, {:error, :inventory_load_failed}}
    end
  end

  @impl true
  def handle_info(:spawn_player, %{character: character, game_state: game_state} = state) do
    # Add player to spatial index at spawn position
    SpatialIndex.add_player(character.id, game_state.x, game_state.y, game_state.map_name)

    # Check initial visibility
    updated_game_state = handle_visibility_update(character, game_state)

    # After initial spawn, transition to standing state
    # This happens after a short delay to ensure spawn packets are processed
    Process.send_after(self(), :complete_spawn, 100)

    {:noreply, update_game_state(state, updated_game_state)}
  end

  @impl true
  def handle_info(:complete_spawn, %{game_state: game_state} = state) do
    # Transition from just_spawned to standing
    updated_game_state = PlayerState.mark_spawn_complete(game_state)
    {:noreply, update_game_state(state, updated_game_state)}
  end

  @impl true
  def handle_info(:movement_tick, %{game_state: %{is_walking: false}} = state) do
    {:noreply, state}
  end

  def handle_info(:movement_tick, %{game_state: %{is_walking: true, walk_path: []}} = state) do
    game_state = PlayerState.stop_walking(state.game_state)
    {:noreply, %{state | game_state: game_state}}
  end

  def handle_info(
        :movement_tick,
        %{character: character, game_state: game_state} = state
      )
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

  def handle_info(
        {:packet, 0x007D, _packet_data},
        %{character: character, connection_pid: connection_pid, game_state: game_state} = state
      ) do
    Logger.debug("Player #{character.id} finished loading map (LoadEndAck)")

    # TODO
    weight_updates = %{
      StatusParams.weight() => 0,
      StatusParams.max_weight() => 1000
    }

    Enum.each(weight_updates, fn {param_id, value} ->
      packet = build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)

    # Send experience and skill point status (sent later in LoadEndAck sequence)
    # TODO: the next base exp and job exp will come from a different place
    experience_updates = %{
      StatusParams.next_base_exp() => 100,
      StatusParams.next_job_exp() => 100,
      StatusParams.skill_point() => character.skill_point
    }

    Enum.each(experience_updates, fn {param_id, value} ->
      packet = build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)

    send_stat_updates(connection_pid, game_state.stats)

    # Send inventory data to client
    send_inventory_data(connection_pid, game_state.inventory_items)

    # TODO: Send remaining initial game data to client
    # - Skill list
    # - Spawn character on map for other players
    # - Send other visible entities

    {:noreply, state}
  end

  def handle_info(
        {:packet, 0x007E, _packet_data},
        %{connection_pid: connection_pid} = state
      ) do
    server_tick = System.system_time(:millisecond) |> rem(0x100000000)

    packet = %Aesir.ZoneServer.Packets.ZcNotifyTime{
      server_tick: server_tick
    }

    send(connection_pid, {:send_packet, packet})

    {:noreply, state}
  end

  def handle_info(
        {:packet, 0x0360, _packet_data},
        %{connection_pid: connection_pid} = state
      ) do
    server_tick = System.system_time(:millisecond) |> rem(0x100000000)

    packet = %Aesir.ZoneServer.Packets.ZcNotifyTime{
      server_tick: server_tick
    }

    send(connection_pid, {:send_packet, packet})

    {:noreply, state}
  end

  def handle_info(
        {:packet, 0x0368, packet_data},
        %{character: character, connection_pid: connection_pid} = state
      ) do
    Logger.debug("Player #{character.id} requesting name for char_id: #{packet_data.char_id}")

    # For now, if it's the player's own account ID, send their name
    # TODO: Look up other players' names from ETS or database
    name =
      if packet_data.char_id == character.account_id do
        character.name
      else
        # Try to look up other players
        # For now, just return empty
        ""
      end

    packet = %Aesir.ZoneServer.Packets.ZcAckReqname{
      char_id: packet_data.char_id,
      name: name
    }

    send(connection_pid, {:send_packet, packet})

    {:noreply, state}
  end

  def handle_info({:packet, 0x035F, packet_data}, state) do
    handle_cast({:request_move, packet_data.dest_x, packet_data.dest_y}, state)
  end

  @impl true
  def handle_info(:connection_closed, %{character: character} = state) do
    Logger.info("Player #{character.id} connection closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(
        {:player_spawned, _spawn_data},
        %{character: _character, connection_pid: _connection_pid} = state
      ) do
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:player_despawned, char_id},
        %{character: character, connection_pid: connection_pid} = state
      ) do
    if char_id != character.id do
      packet = %ZcNotifyVanish{
        gid: char_id,
        type: ZcNotifyVanish.out_of_sight()
      }

      send(connection_pid, {:send_packet, packet})
      Logger.debug("Player #{char_id} vanished from view")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_entered_view, other_char_id}, state) do
    case :ets.lookup(table_for(:zone_players), other_char_id) do
      [{^other_char_id, other_pid, _account_id}] ->
        GenServer.cast(other_pid, {:request_player_info, self(), state.character.id})

      _ ->
        :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:request_player_info, requester_pid, _requester_char_id}, state) do
    info = %{
      character: state.character,
      game_state: state.game_state,
      movement_state: state.game_state.movement_state,
      is_walking: state.game_state.is_walking,
      walk_path: state.game_state.walk_path
    }

    GenServer.cast(requester_pid, {:player_info_response, info, state.character.id})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_info_response, player_info, _from_char_id}, state) do
    # Received player info - now send the spawn packet
    send_player_spawn_packet(state.connection_pid, player_info)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_left_view, _other_char_id, other_account_id}, state) do
    packet = %ZcNotifyVanish{
      gid: other_account_id,
      type: ZcNotifyVanish.out_of_sight()
    }

    send(state.connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:request_move, dest_x, dest_y},
        %{character: character, game_state: game_state, connection_pid: connection_pid} = state
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
        Logger.debug("Player #{character.id} already at destination")
        {:noreply, state}

      {:error, reason} ->
        # No path found or map not loaded
        Logger.debug("Movement failed for player #{character.id}: #{inspect(reason)}")

        packet = %ZcNotifyMoveStop{
          account_id: character.account_id,
          x: game_state.x,
          y: game_state.y
        }

        send(connection_pid, {:send_packet, packet})

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(
        :force_stop_movement,
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

  @impl true
  def handle_cast(
        {:send_packet, packet},
        %{character: character, connection_pid: connection_pid} = state
      ) do
    if connection_pid do
      send(connection_pid, {:send_packet, packet})
    else
      Logger.error("No connection PID for player #{character.id}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:send_status_update, param_id, value},
        %{connection_pid: connection_pid} = state
      ) do
    packet = build_status_packet(param_id, value)
    send(connection_pid, {:send_packet, packet})
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:send_status_updates, status_map},
        %{connection_pid: connection_pid} = state
      ) do
    Enum.each(status_map, fn {param_id, value} ->
      packet = build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:recalculate_stats, %{character: character} = state) do
    # Recalculate stats with player ID for status effects
    updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)

    # Only update and send changes if stats actually changed
    if updated_stats != state.game_state.stats do
      updated_game_state = %{state.game_state | stats: updated_stats}
      send_stat_updates(state.connection_pid, updated_stats)

      {:noreply, update_game_state(state, updated_game_state)}
    else
      # No changes, skip update
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(
        {:update_base_stat, stat_name, new_value},
        _from,
        %{character: character} = state
      ) do
    stats = state.game_state.stats
    updated_base_stats = Map.put(stats.base_stats, stat_name, new_value)
    updated_stats = %{stats | base_stats: updated_base_stats}
    updated_stats = Stats.calculate_stats(updated_stats, character.id)
    updated_game_state = %{state.game_state | stats: updated_stats}
    updated_state = %{state | game_state: updated_game_state}

    send_stat_updates(state.connection_pid, updated_stats)

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:recalculate_stats, _from, %{character: character} = state) do
    updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)
    updated_game_state = %{state.game_state | stats: updated_stats}
    updated_state = %{state | game_state: updated_game_state}

    send_stat_updates(state.connection_pid, updated_stats)

    {:reply, updated_stats, updated_state}
  end

  @impl true
  def handle_call(:get_current_stats, _from, state) do
    {:reply, state.game_state.stats, state}
  end

  @impl true
  def handle_call(
        {:apply_status, status_id, val1, val2, val3, val4, tick, flag, caster_id},
        _from,
        %{character: character} = state
      ) do
    case Interpreter.apply_status(
           :player,
           character.id,
           status_id,
           val1,
           val2,
           val3,
           val4,
           tick,
           flag,
           caster_id
         ) do
      :ok ->
        # Recalculate stats with status effects
        updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)
        updated_game_state = %{state.game_state | stats: updated_stats}

        # Send stat updates to client if they changed
        if updated_stats != state.game_state.stats do
          send_stat_updates(state.connection_pid, updated_stats)
        end

        {:reply, :ok, %{state | game_state: updated_game_state}}

      {:error, reason} ->
        # Status application failed for some reason (e.g., immunity)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:remove_status, status_id}, _from, %{character: character} = state) do
    # Remove the status effect
    Interpreter.remove_status(:player, character.id, status_id)

    # Recalculate stats without this status effect
    updated_stats = Stats.calculate_stats(state.game_state.stats, character.id)
    updated_game_state = %{state.game_state | stats: updated_stats}

    # Send stat updates to client if they changed
    if updated_stats != state.game_state.stats do
      send_stat_updates(state.connection_pid, updated_stats)
    end

    {:reply, :ok, %{state | game_state: updated_game_state}}
  end

  @impl true
  def handle_call(:get_active_statuses, _from, %{character: character} = state) do
    statuses = StatusStorage.get_unit_statuses(:player, character.id)
    {:reply, statuses, state}
  end

  @impl true
  def handle_call({:has_status, status_id}, _from, %{character: character} = state) do
    has_status = StatusStorage.has_status?(:player, character.id, status_id)
    {:reply, has_status, state}
  end

  @impl true
  def terminate(_reason, %{
        character: character,
        game_state: _game_state,
        connection_pid: connection_pid
      }) do
    # Broadcast vanish packet to all visible players before cleanup
    broadcast_vanish_on_disconnect(character)

    # Clean up player data
    :ets.delete(table_for(:zone_players), character.id)
    SpatialIndex.remove_player(character.id)
    SpatialIndex.clear_visibility(character.id)
    UnitRegistry.unregister_unit(:player, character.id)

    if connection_pid && Process.alive?(connection_pid) do
      send(connection_pid, :player_session_terminated)
    end

    :ok
  end

  defp broadcast_vanish_on_disconnect(character) do
    visible_players = SpatialIndex.get_visible_players(character.id)

    vanish_packet = %ZcNotifyVanish{
      gid: character.account_id,
      type: ZcNotifyVanish.logged_out()
    }

    Enum.each(visible_players, fn other_char_id ->
      if other_char_id != character.id do
        send_vanish_to_player(other_char_id, vanish_packet)
      end
    end)
  end

  defp send_vanish_to_player(char_id, packet) do
    case :ets.lookup(table_for(:zone_players), char_id) do
      [{^char_id, pid, _account_id}] ->
        send_packet(pid, packet)

      _ ->
        :ok
    end
  end

  defp build_status_packet(param_id, value) do
    experience_params = [
      StatusParams.base_exp(),
      StatusParams.job_exp(),
      StatusParams.next_base_exp(),
      StatusParams.next_job_exp()
    ]

    if param_id in experience_params do
      %ZcLongparChange{var_id: param_id, value: value}
    else
      %ZcParChange{var_id: param_id, value: value}
    end
  end

  # Helper to update game_state and sync with UnitRegistry
  defp update_game_state(state, new_game_state) do
    # Update UnitRegistry with the new state
    UnitRegistry.update_unit_state(:player, state.character.id, new_game_state)

    # Return the updated state
    %{state | game_state: new_game_state}
  end

  defp register_player(char_id, account_id),
    do: :ets.insert(table_for(:zone_players), {char_id, self(), account_id})

  defp sex_to_int("F"), do: 0
  defp sex_to_int("M"), do: 1
  defp sex_to_int(_), do: 1

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
    case :ets.lookup(table_for(:zone_players), char_id) do
      [{^char_id, pid, _account_id}] ->
        send_packet(pid, packet)

      _ ->
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
      sex: sex_to_int(character.sex),
      x_size: 5,
      y_size: 5,
      clevel: character.base_level,
      font: 0,
      max_hp: game_state.stats.derived_stats.max_hp,
      hp: game_state.stats.current_state.hp,
      is_boss: 0,
      body: 0,
      name: character.name
    }
  end

  defp handle_visibility_update(character, game_state) do
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
    case :ets.lookup(table_for(:zone_players), to_char_id) do
      [{^to_char_id, pid, _account_id}] ->
        GenServer.cast(pid, {:player_entered_view, about_char_id})

      _ ->
        :ok
    end
  end

  defp send_player_spawn_packet(connection_pid, player_info) do
    %{character: character, game_state: game_state} = player_info
    packet = build_spawn_packet(character, game_state)
    send(connection_pid, {:send_packet, packet})
  end

  defp build_spawn_packet(character, game_state) do
    if moving?(game_state) do
      build_moveentry_packet(character, game_state)
    else
      build_stationary_packet(character, game_state)
    end
  end

  defp moving?(game_state) do
    game_state.movement_state == :moving and
      game_state.is_walking and
      length(game_state.walk_path) > 0
  end

  defp build_moveentry_packet(character, game_state) do
    [{dest_x, dest_y} | _] = Enum.reverse(game_state.walk_path)

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
      sex: sex_to_int(character.sex),
      x_size: 5,
      y_size: 5,
      clevel: character.base_level,
      font: 0,
      max_hp: game_state.stats.derived_stats.max_hp,
      hp: game_state.stats.current_state.hp,
      is_boss: 0,
      body: 0,
      name: character.name
    }
  end

  defp build_stationary_packet(character, game_state) do
    case game_state.movement_state do
      :standing -> build_standentry_packet(character, game_state)
      _ -> build_newentry_packet(character, game_state)
    end
  end

  defp build_standentry_packet(character, game_state) do
    %ZcNotifyStandentry{
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
      accessory2: character.head_mid || 0,
      accessory3: 0,
      head_palette: character.hair_color,
      body_palette: character.clothes_color,
      head_dir: 0,
      robe: character.robe || 0,
      guild_id: 0,
      guild_emblem_ver: 0,
      honor: 0,
      virtue: 0,
      is_pk_mode_on: 0,
      sex: sex_to_int(character.sex),
      x: game_state.x,
      y: game_state.y,
      dir: game_state.dir || 0,
      x_size: 5,
      y_size: 5,
      # 0 = standing, 2 = sitting
      state: 0,
      clevel: character.base_level,
      font: 0,
      max_hp: game_state.stats.derived_stats.max_hp,
      hp: game_state.stats.current_state.hp,
      is_boss: 0,
      body: 0,
      name: character.name
    }
  end

  defp build_newentry_packet(character, game_state) do
    %ZcNotifyNewentry{
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
      accessory2: character.head_mid || 0,
      accessory3: 0,
      head_palette: character.hair_color,
      body_palette: character.clothes_color,
      head_dir: 0,
      robe: character.robe || 0,
      guild_id: 0,
      guild_emblem_ver: 0,
      honor: 0,
      virtue: 0,
      is_pk_mode_on: 0,
      sex: sex_to_int(character.sex),
      x: game_state.x,
      y: game_state.y,
      dir: game_state.dir || 0,
      x_size: 5,
      y_size: 5,
      clevel: character.base_level,
      font: 0,
      max_hp: game_state.stats.derived_stats.max_hp,
      hp: game_state.stats.current_state.hp,
      is_boss: 0,
      body: 0,
      name: character.name
    }
  end

  defp send_vanish_packet_to(to_char_id, about_char_id) do
    # Get the player session for the target and the account_id of the vanishing player
    with [{^to_char_id, to_pid, _to_account_id}] <-
           :ets.lookup(table_for(:zone_players), to_char_id),
         [{^about_char_id, _about_pid, about_account_id}] <-
           :ets.lookup(table_for(:zone_players), about_char_id) do
      GenServer.cast(to_pid, {:player_left_view, about_char_id, about_account_id})
    else
      _ -> :ok
    end
  end

  defp send_stat_updates(connection_pid, %Stats{} = stats) do
    status_updates = %{
      # Base stats
      StatusParams.str() => stats.base_stats.str,
      StatusParams.agi() => stats.base_stats.agi,
      StatusParams.vit() => stats.base_stats.vit,
      StatusParams.int() => stats.base_stats.int,
      StatusParams.dex() => stats.base_stats.dex,
      StatusParams.luk() => stats.base_stats.luk,

      # Derived stats
      StatusParams.max_hp() => stats.derived_stats.max_hp,
      StatusParams.max_sp() => stats.derived_stats.max_sp,
      StatusParams.hp() => stats.current_state.hp,
      StatusParams.sp() => stats.current_state.sp,
      StatusParams.aspd() => stats.derived_stats.aspd,

      # Combat stats
      StatusParams.hit() => stats.combat_stats.hit,
      StatusParams.flee1() => stats.combat_stats.flee,
      StatusParams.critical() => stats.combat_stats.critical,
      StatusParams.atk1() => stats.combat_stats.atk,
      StatusParams.def1() => stats.combat_stats.def,

      # Progression
      StatusParams.base_level() => stats.progression.base_level,
      StatusParams.job_level() => stats.progression.job_level,
      StatusParams.base_exp() => stats.progression.base_exp,
      StatusParams.job_exp() => stats.progression.job_exp
    }

    Enum.each(status_updates, fn {param_id, value} ->
      packet = build_status_packet(param_id, value)
      send(connection_pid, {:send_packet, packet})
    end)
  end

  defp send_inventory_data(connection_pid, inventory_items) do
    # Send normal inventory items (non-equipped)
    normal_itemlist = ZcNormalItemlist.from_inventory_items(inventory_items)
    send(connection_pid, {:send_packet, normal_itemlist})

    # Send equipped items
    equipitem_list = ZcEquipitemList.from_inventory_items(inventory_items)
    send(connection_pid, {:send_packet, equipitem_list})

    Logger.debug("Sent inventory data: #{length(inventory_items)} items")
  end
end
