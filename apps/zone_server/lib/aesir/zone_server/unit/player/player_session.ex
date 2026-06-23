defmodule Aesir.ZoneServer.Unit.Player.PlayerSession do
  @moduledoc """
  GenServer managing a single player's session.
  Each player gets their own process for fault isolation and concurrency.
  """

  use GenServer

  require Logger

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  # rAthena NATURAL_HEAL_INTERVAL
  @natural_heal_interval 500

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
  Applies combat damage to this player, updating HP and handling death.
  """
  def apply_damage(pid, damage, attacker_id \\ nil) do
    GenServer.cast(pid, {:apply_damage, damage, attacker_id})
  end

  @doc """
  Drains SP from this player (fire-and-forget), clamping at zero.

  Used by SP-costing status effects such as Energy Coat.
  """
  @spec consume_sp(pid(), non_neg_integer()) :: :ok
  def consume_sp(pid, amount) do
    GenServer.cast(pid, {:consume_sp, amount})
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
          game_state: final_game_state,
          connection_pid: connection_pid,
          connection_monitor_ref: connection_monitor_ref
        }

        register_player(character.id, character.account_id, character.name)

        # Subscribe to this player's event topic. Kill rewards and other
        # player-directed domain events arrive here, keeping emitters
        # (mobs, etc.) decoupled from the player session.
        PubSub.subscribe(Aesir.PubSub, "player:#{character.id}")

        # Subscribe to mob despawns on this map so we can drop a combat target
        # when the mob we were attacking dies.
        # subscribe at spawn; re-subscribe on warp when warps land.
        Broadcast.subscribe_mob_despawns(final_game_state.map_name)

        send(self(), :spawn_player)

        {:ok, state}

      {:error, reason} ->
        {:stop, {:error, reason}}
    end
  end

  @impl true
  def handle_info(:spawn_player, %{game_state: game_state} = state) do
    # Add player to spatial index at spawn position
    SpatialIndex.add_player(
      game_state.character_id,
      game_state.x,
      game_state.y,
      game_state.map_name
    )

    # Publish our full state to the registry before visibility runs so players
    # we enter view of can read it to build our spawn packet.
    state = update_game_state(state, game_state)

    # Check initial visibility for players and mobs
    updated_game_state = MovementHandler.handle_visibility_update(state.game_state)

    # After initial spawn, transition to standing state
    # This happens after a short delay to ensure spawn packets are processed
    Process.send_after(self(), :complete_spawn, 100)

    # Start the recurring natural-heal regen tick.
    Process.send_after(self(), :natural_heal_tick, @natural_heal_interval)

    {:noreply, update_game_state(state, updated_game_state)}
  end

  @impl true
  def handle_info(:respawn_after_warp, %{game_state: game_state} = state) do
    # Re-enter the world on the destination map after a warp. Unlike
    # :spawn_player this does not (re)schedule the natural-heal / spawn timers —
    # those chains are already running from the initial spawn and must not stack.
    SpatialIndex.add_player(
      game_state.character_id,
      game_state.x,
      game_state.y,
      game_state.map_name
    )

    state = update_game_state(state, game_state)
    updated_game_state = MovementHandler.handle_visibility_update(state.game_state)

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

  @impl true
  def handle_info(:natural_heal_tick, state) do
    Process.send_after(self(), :natural_heal_tick, @natural_heal_interval)
    NaturalHealHandler.handle_tick(state, @natural_heal_interval)
  end

  def handle_info(:movement_completed, %{game_state: game_state} = state) do
    Logger.debug(
      "Movement completed - action_state: #{game_state.action_state}, movement_intent: #{game_state.movement_intent}, combat_target: #{game_state.combat_target_id}"
    )

    # Save position to database asynchronously
    CharacterPersistence.update_position(
      game_state.character_id,
      game_state.x,
      game_state.y,
      game_state.map_name,
      async: true
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

  def handle_info({:message, message}, state) do
    PacketHandler.handle_message(message, state)
  end

  @impl true
  def handle_info({:cast_complete, token}, state) do
    SkillHandler.handle_cast_complete(state, token)
  end

  @impl true
  def handle_info({:mob_killed, %{base_exp: base_exp, job_exp: job_exp}}, state) do
    ExperienceHandler.handle_gain_exp(base_exp, job_exp, state)
  end

  @impl true
  def handle_info(:recalculate_stats, state) do
    StatsManager.handle_recalculate_stats(state)
  end

  @impl true
  def handle_info({:mob_despawned, mob_instance_id}, state) do
    # Only clear combat if this player was targeting this specific mob
    if state.game_state.combat_target_id == mob_instance_id do
      Logger.debug(
        "Clearing combat target #{mob_instance_id} for player #{state.game_state.character_id}"
      )

      updated_game_state = PlayerState.clear_combat_intent(state.game_state)
      {:ok, idle_state} = PlayerState.transition_to(updated_game_state, :idle)
      {:noreply, %{state | game_state: idle_state}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connection_closed, %{game_state: game_state} = state) do
    Logger.info("Player #{game_state.character_id} connection closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{game_state: game_state} = state) do
    Logger.info("Player #{game_state.character_id} connection process died")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(
        {:player_spawned, _spawn_data},
        %{connection_pid: _connection_pid} = state
      ) do
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:player_despawned, char_id},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    if char_id != game_state.character_id do
      packet = %UnitDespawn{
        gid: char_id,
        reason: DespawnReason.out_of_sight()
      }

      MessageRouter.send_to(connection_pid, packet)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_entered_view, other_char_id}, state) do
    # Read the other player's state straight from the registry instead of
    # round-tripping through their process to fetch it.
    case UnitRegistry.get_unit(:player, other_char_id) do
      {:ok, {_module, %PlayerState{} = other_game_state, _pid}} ->
        send_player_spawn_packet(state.connection_pid, other_game_state)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_left_view, other_char_id, _other_account_id}, state) do
    packet = %UnitDespawn{
      gid: other_char_id,
      reason: DespawnReason.out_of_sight()
    }

    MessageRouter.send_to(state.connection_pid, packet)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:knocked_back, x, y}, %{game_state: game_state} = state) do
    updated_game_state =
      game_state
      |> PlayerState.update_position(x, y)
      |> PlayerState.stop_walking()

    Movement.set_position(
      :player,
      updated_game_state.character_id,
      updated_game_state,
      updated_game_state.map_name
    )

    {:noreply, %{state | game_state: updated_game_state}}
  end

  @impl true
  def handle_cast({:request_move, dest_x, dest_y}, state) do
    MovementHandler.handle_request_move(state, dest_x, dest_y)
  end

  @impl true
  def handle_cast({:use_skill, skill_id, level, target_id}, state) do
    SkillHandler.handle_use_skill(state, skill_id, level, target_id)
  end

  @impl true
  def handle_cast({:learn_skill, skill_id}, state) do
    SkillLearningHandler.handle_learn_skill(skill_id, state)
  end

  @impl true
  def handle_cast({:warp, map_name, x, y}, state) do
    case WarpHandler.warp(state, map_name, x, y) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:use_skill_ground, skill_id, level, x, y}, state) do
    SkillHandler.handle_use_skill_ground(state, skill_id, level, x, y)
  end

  def handle_cast({:request_attack, target_id, action}, state) do
    # Delegate to CombatActionHandler for state machine based combat
    CombatActionHandler.handle_attack_request(state, target_id, action)
  end

  @impl true
  def handle_cast({:equip_item, client_index, position}, state) do
    EquipmentHandler.handle_equip(PlayerState.server_index(client_index), position, state)
  end

  @impl true
  def handle_cast({:unequip_item, client_index}, state) do
    EquipmentHandler.handle_unequip(PlayerState.server_index(client_index), state)
  end

  @impl true
  def handle_cast({:give_item, item_def, amount}, state) do
    InventoryManager.handle_give_item(item_def, amount, state)
  end

  @impl true
  def handle_cast({:apply_damage, damage, attacker_id}, state) do
    HealthHandler.apply_damage(damage, attacker_id, state)
  end

  @impl true
  def handle_cast({:consume_sp, amount}, state) do
    HealthHandler.consume_sp(amount, state)
  end

  @impl true
  def handle_cast(:force_stop_movement, state) do
    MovementHandler.handle_force_stop_movement(state)
  end

  @impl true
  def handle_cast(
        {:send_packet, packet},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    if connection_pid do
      MessageRouter.send_to(connection_pid, packet)
    else
      raise "No connection PID for player #{game_state.character_id}"
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
        game_state: game_state,
        connection_monitor_ref: connection_monitor_ref
      }) do
    Process.demonitor(connection_monitor_ref, [:flush])

    # Save final position to database (synchronous to ensure it's persisted)
    CharacterPersistence.update_position(
      game_state.character_id,
      game_state.x,
      game_state.y,
      game_state.map_name
    )

    WarpHandler.leave_current_map(game_state, DespawnReason.logged_out())

    # Clean up player data
    UnitRegistry.unregister_player(game_state.character_id)

    :ok
  end

  defp update_game_state(state, new_game_state) do
    UnitRegistry.update_unit_state(:player, new_game_state.character_id, new_game_state)

    %{state | game_state: new_game_state}
  end

  defp register_player(char_id, account_id, char_name),
    do: UnitRegistry.register_player(char_id, account_id, char_name, self())

  defp sex_to_int("F"), do: 0
  defp sex_to_int("M"), do: 1
  defp sex_to_int(_), do: 1

  defp send_player_spawn_packet(connection_pid, game_state) do
    packet = build_unit_spawn(game_state)
    MessageRouter.send_to(connection_pid, packet)
  end

  defp build_unit_spawn(game_state) do
    %UnitSpawn{
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
      accessory: game_state.head_bottom,
      accessory2: game_state.head_mid,
      accessory3: 0,
      head_palette: game_state.hair_color,
      body_palette: game_state.clothes_color,
      head_dir: 0,
      robe: game_state.robe,
      guild_id: 0,
      sex: sex_to_int(game_state.sex),
      x: game_state.x,
      y: game_state.y,
      dir: game_state.dir || 0,
      clevel: game_state.stats.progression.base_level,
      max_hp: game_state.stats.derived_stats.max_hp,
      hp: game_state.stats.current_state.hp,
      is_boss: false,
      name: game_state.character_name,
      moving: false
    }
  end
end
