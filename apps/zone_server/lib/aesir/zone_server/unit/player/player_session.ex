defmodule Aesir.ZoneServer.Unit.Player.PlayerSession do
  @moduledoc """
  GenServer managing a single player's session.
  Each player gets their own process for fault isolation and concurrency.
  """

  use GenServer

  require Logger

  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Packets.ZcNotifyMoveentry
  alias Aesir.ZoneServer.Packets.ZcNotifyNewentry
  alias Aesir.ZoneServer.Packets.ZcNotifyStandentry
  alias Aesir.ZoneServer.Packets.ZcNotifyVanish
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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
    GenServer.call(pid, :recalculate_stats)
  end

  def recalculate_stats(pid, false) do
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

  ## Parameters
  - pid: Player session process ID
  - status_id: The status effect ID
  - status_params: Keyword list containing status parameters

  ## Returns
  :ok | {:error, atom()}
  """
  def apply_status(pid, status_id, status_params \\ []) do
    GenServer.call(pid, {:apply_status, status_id, status_params})
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

    case InventoryManager.load_character_inventory(character, game_state) do
      {:ok, updated_game_state} ->
        final_game_state = PlayerState.set_process_pid(updated_game_state, self())

        # Monitor the connection process to detect crashes
        connection_monitor_ref = Process.monitor(connection_pid)

        state = %{
          character: character,
          game_state: final_game_state,
          connection_pid: connection_pid,
          connection_monitor_ref: connection_monitor_ref
        }

        register_player(character.id, character.account_id, character.name)

        send(self(), :spawn_player)

        {:ok, state}

      {:error, reason} ->
        {:stop, {:error, reason}}
    end
  end

  @impl true
  def handle_info(:spawn_player, %{character: character, game_state: game_state} = state) do
    # Add player to spatial index at spawn position
    SpatialIndex.add_player(character.id, game_state.x, game_state.y, game_state.map_name)

    # Check initial visibility for players and mobs
    updated_game_state = MovementHandler.handle_visibility_update(character, game_state)

    # After initial spawn, transition to standing state
    # This happens after a short delay to ensure spawn packets are processed
    Process.send_after(self(), :complete_spawn, 100)

    {:noreply, update_game_state(state, updated_game_state)}
  end

  @impl true
  def handle_info(:complete_spawn, %{game_state: game_state} = state) do
    updated_game_state = PlayerState.mark_spawn_complete(game_state)
    {:noreply, update_game_state(state, updated_game_state)}
  end

  @impl true
  def handle_info(:movement_tick, state) do
    MovementHandler.handle_movement_tick(state)
  end

  def handle_info(:movement_completed, %{game_state: game_state} = state) do
    Logger.debug(
      "Movement completed - action_state: #{game_state.action_state}, movement_intent: #{game_state.movement_intent}, combat_target: #{game_state.combat_target_id}"
    )

    # Orchestrate based on action state and movement intent
    case {game_state.action_state, game_state.movement_intent} do
      {:combat_moving, :combat} when game_state.combat_target_id != nil ->
        # Combat movement completed, attempt attack
        Logger.debug("Combat movement completed, calling handle_reached_attack_position")
        CombatActionHandler.handle_reached_attack_position(state)

      {:moving, _} ->
        # Normal movement completed, transition to idle
        Logger.debug("Normal movement completed, transitioning to idle")

        case PlayerState.transition_to(game_state, :idle) do
          {:ok, transitioned_state} ->
            {:noreply, %{state | game_state: transitioned_state}}

          _ ->
            {:noreply, state}
        end

      other ->
        # Already in appropriate state or unexpected state
        Logger.debug("Movement completed but in unexpected state: #{inspect(other)}")
        {:noreply, state}
    end
  end

  def handle_info({:packet, packet_id, packet_data}, state) do
    PacketHandler.handle_packet(packet_id, packet_data, state)
  end

  @impl true
  def handle_info(:connection_closed, %{character: character} = state) do
    Logger.info("Player #{character.id} connection closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{character: character} = state) do
    Logger.info("Player #{character.id} connection process died")
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
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_entered_view, other_char_id}, state) do
    case UnitRegistry.get_player_pid(other_char_id) do
      {:ok, other_pid} ->
        GenServer.cast(other_pid, {:request_player_info, self(), state.character.id})

      {:error, :not_found} ->
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
      walk_path: state.game_state.walk_path
    }

    GenServer.cast(requester_pid, {:player_info_response, info, state.character.id})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_info_response, player_info, _from_char_id}, state) do
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
  def handle_cast({:request_move, dest_x, dest_y}, state) do
    MovementHandler.handle_request_move(state, dest_x, dest_y)
  end

  def handle_cast({:request_attack, target_id, action}, state) do
    # Delegate to CombatActionHandler for state machine based combat
    CombatActionHandler.handle_attack_request(state, target_id, action)
  end

  @impl true
  def handle_cast(:force_stop_movement, state) do
    MovementHandler.handle_force_stop_movement(state)
  end

  @impl true
  def handle_cast(
        {:send_packet, packet},
        %{character: character, connection_pid: connection_pid} = state
      ) do
    if connection_pid do
      send(connection_pid, {:send_packet, packet})
    else
      raise "No connection PID for player #{character.id}"
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_status_update, param_id, value}, state) do
    StatsManager.handle_send_status_update(param_id, value, state)
  end

  @impl true
  def handle_cast({:send_status_updates, status_map}, state) do
    StatsManager.handle_send_status_updates(status_map, state)
  end

  @impl true
  def handle_cast(:recalculate_stats, state) do
    StatsManager.handle_recalculate_stats(state)
  end

  @impl true
  def handle_cast({:clear_combat_target, mob_instance_id}, state) do
    # Only clear combat if this player was targeting this specific mob
    if state.game_state.combat_target_id == mob_instance_id do
      Logger.debug("Clearing combat target #{mob_instance_id} for player #{state.character.id}")
      updated_game_state = PlayerState.clear_combat_intent(state.game_state)
      {:ok, idle_state} = PlayerState.transition_to(updated_game_state, :idle)
      {:noreply, %{state | game_state: idle_state}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_base_stat, stat_name, new_value}, _from, state) do
    StatsManager.handle_update_base_stat(stat_name, new_value, state)
  end

  @impl true
  def handle_call(:recalculate_stats, _from, state) do
    StatsManager.handle_sync_recalculate_stats(state)
  end

  @impl true
  def handle_call(:get_current_stats, _from, state) do
    StatsManager.handle_get_current_stats(state)
  end

  @impl true
  def handle_call({:apply_status, status_id, status_params}, _from, state) do
    StatusManager.handle_apply_status(status_id, status_params, state)
  end

  @impl true
  def handle_call({:remove_status, status_id}, _from, state) do
    StatusManager.handle_remove_status(status_id, state)
  end

  @impl true
  def handle_call(:get_active_statuses, _from, state) do
    StatusManager.handle_get_active_statuses(state)
  end

  @impl true
  def handle_call({:has_status, status_id}, _from, state) do
    StatusManager.handle_has_status(status_id, state)
  end

  @impl true
  def terminate(_reason, %{
        character: character,
        game_state: _game_state,
        connection_pid: connection_pid,
        connection_monitor_ref: connection_monitor_ref
      }) do
    Process.demonitor(connection_monitor_ref, [:flush])
    broadcast_vanish_on_disconnect(character)

    # Clean up player data
    UnitRegistry.unregister_player(character.id)
    SpatialIndex.remove_player(character.id)
    SpatialIndex.clear_visibility(character.id)

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
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} ->
        send_packet(pid, packet)

      {:error, :not_found} ->
        :ok
    end
  end

  defp update_game_state(state, new_game_state) do
    UnitRegistry.update_unit_state(:player, state.character.id, new_game_state)

    %{state | game_state: new_game_state}
  end

  defp register_player(char_id, account_id, char_name),
    do: UnitRegistry.register_player(char_id, account_id, char_name, self())

  defp sex_to_int("F"), do: 0
  defp sex_to_int("M"), do: 1
  defp sex_to_int(_), do: 1

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
      length(game_state.walk_path) > 0
  end

  defp build_moveentry_packet(character, game_state) do
    [{dest_x, dest_y} | _] = Enum.reverse(game_state.walk_path)

    %ZcNotifyMoveentry{
      object_type: ObjectType.pc(),
      aid: character.account_id,
      gid: character.id,
      speed: game_state.walk_speed,
      body_state: 0,
      health_state: 0,
      effect_state: 0,
      job: character.class,
      head: character.hair,
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
      object_type: ObjectType.pc(),
      aid: character.account_id,
      gid: character.id,
      speed: game_state.walk_speed,
      body_state: 0,
      health_state: 0,
      effect_state: 0,
      job: character.class,
      head: character.hair,
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
      object_type: ObjectType.pc(),
      aid: character.account_id,
      gid: character.id,
      speed: game_state.walk_speed,
      body_state: 0,
      health_state: 0,
      effect_state: 0,
      job: character.class,
      head: character.hair,
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
end
