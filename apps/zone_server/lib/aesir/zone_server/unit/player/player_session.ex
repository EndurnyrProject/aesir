defmodule Aesir.ZoneServer.Unit.Player.PlayerSession do
  @moduledoc """
  GenServer managing a single player's session.
  Each player gets their own process for fault isolation and concurrency.
  """

  use GenServer
  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Events
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Packets.ZcLongparChange
  alias Aesir.ZoneServer.Packets.ZcParChange
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex

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
  """
  def recalculate_stats(pid) do
    GenServer.call(pid, :recalculate_stats)
  end

  @doc """
  Gets the current Stats struct.
  """
  def get_current_stats(pid) do
    GenServer.call(pid, :get_current_stats)
  end

  @impl true
  def init(args) do
    character = args[:character]
    connection_pid = args[:connection_pid]
    game_state = PlayerState.new(character)

    state = %{
      character: character,
      game_state: game_state,
      connection_pid: connection_pid
    }

    # Register in ETS tables
    register_player(character.id)

    # Subscribe to map events
    Events.Player.subscribe_to_map(game_state.map_name)

    # Start spawn sequence
    send(self(), :spawn_player)

    {:ok, state}
  end

  @impl true
  def handle_info(:spawn_player, %{character: character, game_state: game_state} = state) do
    # Update position in spatial index
    SpatialIndex.update_position(character.id, game_state.x, game_state.y, game_state.map_name)

    # Subscribe to visible cells
    new_cells = Geometry.visible_cells(game_state.x, game_state.y, game_state.view_range)
    Events.Movement.subscribe_to_cells(game_state.map_name, new_cells)
    game_state = %{game_state | subscribed_cells: new_cells}

    # Notify other players in range about spawn
    Events.Player.broadcast_spawn(character, game_state)

    # Send spawn acknowledgment to client
    # TODO: Send ZC_ACCEPT_ENTER packet

    {:noreply, %{state | game_state: game_state}}
  end

  @impl true
  def handle_info(:movement_tick, %{game_state: %{is_walking: false}} = state) do
    {:noreply, state}
  end

  def handle_info(:movement_tick, %{game_state: %{is_walking: true, walk_path: []}} = state) do
    game_state = PlayerState.stop_walking(state.game_state)
    {:noreply, %{state | game_state: game_state}}
  end

  def handle_info(:movement_tick, %{character: character, game_state: game_state} = state)
      when game_state.is_walking do
    [next | rest] = game_state.walk_path
    {next_x, next_y} = next
    old_x = game_state.x
    old_y = game_state.y

    # Update position and direction
    game_state = PlayerState.update_position(game_state, next_x, next_y)
    game_state = %{game_state | walk_path: rest}
    dir = Geometry.calculate_direction(old_x, old_y, next_x, next_y)
    game_state = PlayerState.update_direction(game_state, dir)

    # Update spatial index
    SpatialIndex.update_position(character.id, next_x, next_y, game_state.map_name)

    # Update cell subscriptions if needed
    game_state = update_cell_subscriptions(game_state)

    # Broadcast movement to others
    Events.Movement.broadcast_position_update(character.id, game_state, old_x, old_y)

    # Schedule next tick or stop if done
    if rest == [] do
      game_state = PlayerState.stop_walking(game_state)
      Events.Movement.broadcast_stop(character.id, game_state)
    else
      Process.send_after(self(), :movement_tick, game_state.walk_speed)
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

    # TODO: Send remaining initial game data to client
    # - Inventory list
    # - Equipment list
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
  def handle_info({:player_spawned, spawn_data}, %{character: character} = state) do
    if spawn_data.char_id != character.id do
      # TODO: Send ZC_NOTIFY_PLAYERMOVE packet
      Logger.debug("Player #{spawn_data.char_id} spawned in view")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:player_moved, char_id, from_x, from_y, to_x, to_y},
        %{character: character} = state
      ) do
    if char_id != character.id do
      # TODO: Send ZC_NOTIFY_PLAYERMOVE packet
      Logger.debug("Player #{char_id} moved from (#{from_x},#{from_y}) to (#{to_x},#{to_y})")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:player_despawned, char_id}, %{character: character} = state) do
    if char_id != character.id do
      # TODO: Send ZC_NOTIFY_VANISH packet
      Logger.debug("Player #{char_id} vanished from view")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:player_stopped, char_id, x, y}, %{character: character} = state) do
    if char_id != character.id do
      # TODO: Send ZC_NOTIFY_MOVE_STOP packet
      Logger.debug("Player #{char_id} stopped at (#{x},#{y})")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:request_move, dest_x, dest_y},
        %{character: character, game_state: game_state} = state
      ) do
    case calculate_path(game_state.map_name, game_state.x, game_state.y, dest_x, dest_y) do
      {:ok, path} ->
        game_state = PlayerState.set_path(game_state, path)

        if game_state.is_walking do
          send_movement_packet(
            state.connection_pid,
            character.account_id,
            game_state,
            dest_x,
            dest_y
          )

          Process.send_after(self(), :movement_tick, game_state.walk_speed)
        end

        {:noreply, %{state | game_state: game_state}}

      {:error, reason} ->
        Logger.debug("Player #{character.id} pathfinding failed: #{reason}")
        # TODO: Send ZC_NOTIFY_MOVE_STOP or error packet
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
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_base_stat, stat_name, new_value}, _from, state) do
    stats = state.game_state.stats
    updated_base_stats = Map.put(stats.base_stats, stat_name, new_value)
    updated_stats = %{stats | base_stats: updated_base_stats}

    # Recalculate all derived stats
    updated_stats = Stats.calculate_stats(updated_stats)

    # Update game state
    updated_game_state = %{state.game_state | stats: updated_stats}
    updated_state = %{state | game_state: updated_game_state}

    # Send stat updates to client
    send_stat_updates(state.connection_pid, updated_stats)

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:recalculate_stats, _from, state) do
    updated_stats = Stats.calculate_stats(state.game_state.stats)
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
  def terminate(_reason, %{
        character: character,
        game_state: game_state,
        connection_pid: connection_pid
      }) do
    # Clean up ETS entry
    :ets.delete(:zone_players, character.id)

    # Clean up on disconnect
    SpatialIndex.remove_player(character.id)
    Events.Movement.unsubscribe_from_cells(game_state.map_name, game_state.subscribed_cells)
    Events.Player.broadcast_despawn(character.id, game_state)

    # Notify connection process if still alive
    if connection_pid && Process.alive?(connection_pid) do
      send(connection_pid, :player_session_terminated)
    end

    :ok
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

  defp register_player(char_id), do: :ets.insert(:zone_players, {char_id, self()})

  defp update_cell_subscriptions(game_state) do
    new_cells = Geometry.visible_cells(game_state.x, game_state.y, game_state.view_range)
    old_cells = game_state.subscribed_cells

    # Find cells to subscribe/unsubscribe
    to_subscribe = new_cells -- old_cells
    to_unsubscribe = old_cells -- new_cells

    # Update subscriptions
    Events.Movement.unsubscribe_from_cells(game_state.map_name, to_unsubscribe)
    Events.Movement.subscribe_to_cells(game_state.map_name, to_subscribe)

    %{game_state | subscribed_cells: new_cells}
  end

  defp calculate_path(map_name, from_x, from_y, to_x, to_y) do
    case MapCache.get(map_name) do
      {:ok, map_data} ->
        Pathfinding.find_path(map_data, {from_x, from_y}, {to_x, to_y})

      {:error, :not_found} ->
        Logger.error("Map #{map_name} not found in cache")
        {:error, :map_not_found}
    end
  end

  defp send_movement_packet(connection_pid, _account_id, game_state, dest_x, dest_y) do
    packet = %Aesir.ZoneServer.Packets.ZcNotifyPlayermove{
      walk_start_time: System.system_time(:millisecond),
      src_x: game_state.x,
      src_y: game_state.y,
      dst_x: dest_x,
      dst_y: dest_y
    }

    send(connection_pid, {:send_packet, packet})
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
end
