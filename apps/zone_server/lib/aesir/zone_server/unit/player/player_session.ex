defmodule Aesir.ZoneServer.Unit.Player.PlayerSession do
  @moduledoc """
  GenServer managing a single player's session.
  Each player gets their own process for fault isolation and concurrency.

  Restart is `:temporary`: a player session is bound to a live connection and a
  freshly loaded character. If it crashes there is no safe state to restart from
  (the in-memory game state is gone and the original args are stale), so instead
  the owning connection is torn down and the client must reconnect.
  """

  use GenServer, restart: :temporary

  require Logger

  alias Aesir.Net.ItemVanished
  alias Aesir.Net.PartyDisbanded
  alias Aesir.Net.PartyInfo
  alias Aesir.Net.PartyMember
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.VendingBoardShown
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Appearance
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcOwnerEventHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PartyHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending.Registry, as: VendingRegistry
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
  Runs an attached NPC event for this player session on `module`'s `gid`
  (currently only `Map.Coordinator`'s OnMyMobDead owner-event dispatch, fired
  when a mob tagged with `event:` dies to this player).
  """
  @spec run_attached_event(pid(), module(), non_neg_integer(), String.t()) :: :ok
  def run_attached_event(pid, module, gid, label) do
    GenServer.cast(pid, {:run_attached_event, module, gid, label})
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

  @doc """
  Delivers a pending party invite to this player's session: stores it, sends
  the `PartyInviteNotify`, and arms its 30s expiry timer. Rejects a second
  invite while one is already pending and unexpired.
  """
  @spec deliver_party_invite(pid(), map()) :: :ok | {:error, :invite_pending}
  def deliver_party_invite(pid, invite) do
    GenServer.call(pid, {:deliver_party_invite, invite})
  end

  @doc """
  Subscribes the calling session to a party it just created or joined
  mid-session, updates `game_state.party_id`, and sends the initial
  `PartyInfo` snapshot. Must run inside the owning `PlayerSession` process
  (e.g. from `PartyHandler`, which executes inline during packet dispatch).
  Mirrors what `subscribe_party/1` does for a party already recorded at
  login -- `ensure_started`/`set_online` aren't needed here since the caller
  already holds a freshly-created/joined, already-online `Party.State`.
  """
  @spec attach_to_party(map(), PartyState.t()) :: map()
  def attach_to_party(%{game_state: game_state} = state, %PartyState{} = party_state) do
    PubSub.subscribe(Aesir.PubSub, "party:#{party_state.party_id}")
    MessageRouter.send_to(state.connection_pid, build_party_info(party_state))
    update_game_state(state, %{game_state | party_id: party_state.party_id})
  end

  @impl true
  def init(args) do
    character = args[:character]
    connection_pid = args[:connection_pid]
    game_state = PlayerState.new(character)

    {:ok, updated_game_state} = InventoryManager.load_character_inventory(character, game_state)
    final_game_state = PlayerState.set_process_pid(updated_game_state, self())

    # Monitor the connection process to detect crashes
    connection_monitor_ref = Process.monitor(connection_pid)

    state = %{
      game_state: final_game_state,
      connection_pid: connection_pid,
      connection_monitor_ref: connection_monitor_ref,
      interaction_lock: nil
    }

    register_player(final_game_state)

    # Restore a mounted cart: load its rows, set the tier, and re-apply
    # SC_PUSHCART so the sprite folds into the spawn effect_state and the
    # walk-speed penalty is recomputed. Runs after registration so the
    # status apply can resolve the unit's entity info.
    state = CartHandler.load_on_spawn(character, state)

    # Subscribe to this player's event topic. Kill rewards and other
    # player-directed domain events arrive here, keeping emitters
    # (mobs, etc.) decoupled from the player session.
    PubSub.subscribe(Aesir.PubSub, "player:#{character.id}")

    # Join the party's presence topic and send the initial snapshot when the
    # character is party'd. A missing party row or a live party that no
    # longer lists this character (kicked while offline) silently resets
    # `party_id` back to 0 instead of subscribing (design "Login/logout").
    state = subscribe_party(state)

    # Subscribe to mob despawns on this map so we can drop a combat target
    # when the mob we were attacking dies.
    # subscribe at spawn; re-subscribe on warp when warps land.
    Broadcast.subscribe_mob_despawns(state.game_state.map_name)

    send(self(), :spawn_player)

    {:ok, state}
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
        CombatActionHandler.handle_reached_attack_position(state)

      {:skill_moving, :skill} ->
        # Reached casting range, dispatch the pending skill
        SkillHandler.handle_reached_skill_position(state)

      {:moving_to_item, :pickup} when game_state.pickup_target_id != nil ->
        # Reached the ground item, attempt pickup
        PickupHandler.handle_reached_item(state)

      {:moving, _} ->
        # Normal movement completed, transition to idle
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
  def handle_info({:auto_attack, target_id}, state) do
    CombatActionHandler.handle_auto_attack(state, target_id)
  end

  @impl true
  def handle_info({:cast_complete, token}, state) do
    SkillHandler.handle_cast_complete(state, token)
  end

  # EXP for the kill is granted separately, per contributing attacker, via
  # `{:mob_kill_exp, base, job}` (`Unit.Mob.KillExp.distribute/5`); this
  # handler only rolls and places this session's own drops as the killing
  # blow's attacker.
  @impl true
  def handle_info({:mob_killed, payload}, state) do
    maybe_drop_items(payload, state)
    {:noreply, state}
  end

  # A contributing attacker's final damage-based EXP grant for a mob kill
  # (`Unit.Mob.KillExp.distribute/5`, design "Damage-based EXP share"),
  # already scaled by the damage/bonus/penalty (or party pool/bonus/penalty)
  # math -- applied as-is.
  @impl true
  def handle_info({:mob_kill_exp, base, job}, state) do
    ExperienceHandler.handle_gain_exp(base, job, state)
  end

  # A membership or option change on our own live party: relay the fresh
  # `PartyInfo` snapshot. If we're no longer listed among the members (an
  # ordinary kick/leave while online), unsubscribe and clear `party_id`
  # instead so the topic subscription doesn't leak (design "Flows": Kick,
  # Leave).
  @impl true
  def handle_info(
        {:party_updated, %PartyState{party_id: party_id} = party_state},
        %{game_state: %{party_id: party_id, character_id: char_id} = game_state} = state
      ) do
    if Map.has_key?(party_state.members, char_id) do
      MessageRouter.send_to(state.connection_pid, build_party_info(party_state))
      {:noreply, state}
    else
      PubSub.unsubscribe(Aesir.PubSub, "party:#{party_id}")
      {:noreply, update_game_state(state, %{game_state | party_id: 0})}
    end
  end

  # A stale broadcast for a party we've already left/switched away from.
  @impl true
  def handle_info({:party_updated, %PartyState{}}, state), do: {:noreply, state}

  @impl true
  def handle_info(
        {:party_disbanded, party_id, reason},
        %{game_state: %{party_id: party_id} = game_state} = state
      ) do
    MessageRouter.send_to(state.connection_pid, %PartyDisbanded{
      party_id: party_id,
      reason: reason
    })

    PubSub.unsubscribe(Aesir.PubSub, "party:#{party_id}")
    {:noreply, update_game_state(state, %{game_state | party_id: 0})}
  end

  @impl true
  def handle_info({:party_disbanded, _party_id, _reason}, state), do: {:noreply, state}

  @impl true
  def handle_info(:party_invite_expired, state) do
    {:noreply, Map.delete(state, :pending_party_invite)}
  end

  @impl true
  def handle_info(:recalculate_stats, state) do
    StatsManager.handle_recalculate_stats(state)
  end

  @impl true
  def handle_info({:apply_heal, amount, source_id}, state) do
    HealthHandler.apply_heal(amount, source_id, state)
  end

  @impl true
  def handle_info({:change_job, job_id}, state) do
    ProgressionHandler.handle_change_job(job_id, state)
  end

  @impl true
  def handle_info({:reset_skills}, state) do
    case ProgressionHandler.reset_skills(state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
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

  # The active NPC interaction ended (close / idle-timeout / crash). Clearing the
  # lock frees the player to talk to NPCs again; the session always survives
  # (this monitor never propagates the interaction's exit). Matched ahead of the
  # connection :DOWN below so a finished dialog isn't mistaken for a dropped
  # connection.
  @impl true
  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %{interaction_lock: {_lock_pid, ref, _gid}} = state
      ) do
    {:noreply, %{state | interaction_lock: nil}}
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
        send_active_icons(:player, other_char_id, state.game_state.character_id)
        maybe_send_vending_board(state.connection_pid, other_char_id)

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
  def handle_cast({:warp, map_name, x, y}, state) do
    case WarpHandler.warp(state, map_name, x, y) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:give_item, item_def, amount}, state) do
    case InventoryManager.handle_give_item(item_def, amount, state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason, unchanged_state} -> {:noreply, unchanged_state}
    end
  end

  @impl true
  def handle_cast({:apply_damage, damage, attacker_id}, state) do
    HealthHandler.apply_damage(damage, attacker_id, state)
  end

  @impl true
  def handle_cast({:add_base_level, amount}, state) do
    ProgressionHandler.handle_add_base_level(amount, state)
  end

  @impl true
  def handle_cast({:add_job_level, amount}, state) do
    ProgressionHandler.handle_add_job_level(amount, state)
  end

  @impl true
  def handle_cast({:consume_sp, amount}, state) do
    HealthHandler.consume_sp(amount, state)
  end

  @impl true
  def handle_cast({:run_attached_event, module, gid, label}, state) do
    NpcOwnerEventHandler.run(module, gid, label, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:force_stop_movement, state) do
    MovementHandler.handle_force_stop_movement(state)
  end

  # A Coordinator-broadcast ground-item vanish: forward it like any other packet
  # but also drop the id from `visible_items` so re-entering the cell's range
  # later re-spawns the item via the walk-up diff.
  @impl true
  def handle_cast(
        {:send_packet, %ItemVanished{ground_id: ground_id} = packet},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    if connection_pid do
      MessageRouter.send_to(connection_pid, packet)
    end

    game_state = %{game_state | visible_items: MapSet.delete(game_state.visible_items, ground_id)}

    {:noreply, %{state | game_state: game_state}}
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

  # The single-writer effect seam: an NPC interaction process applies a state
  # mutation (pay_zeny / give_item / delitem / set_char_var) against this
  # authoritative session. Replies with the fresh game_state or an error; on
  # success the new game_state is also published to the unit registry.
  # The seller-authority buy seam: a buyer session (parked in its own cast)
  # calls this on the seller session, which runs the whole atomic transaction
  # and replies with the buyer's delta. `purchase/7` already pushed the seller's
  # own cart/zeny packets; the per-line `VendingSaleReport`s are returned for us
  # to deliver to the seller's client here.
  @impl true
  def handle_call(
        {:vending_purchase, buyer_char_id, buyer_inventory, buyer_zeny, buyer_stats, buyer_name,
         buy_lines},
        _from,
        seller_state
      ) do
    case VendingHandler.purchase(
           seller_state,
           buyer_char_id,
           buyer_inventory,
           buyer_zeny,
           buyer_stats,
           buyer_name,
           buy_lines
         ) do
      {:ok, new_seller_state, buyer_delta, sale_reports} ->
        Enum.each(sale_reports, &MessageRouter.send_to(new_seller_state.connection_pid, &1))

        {:reply, {:ok, buyer_delta},
         update_game_state(new_seller_state, new_seller_state.game_state)}

      {:error, reason} ->
        {:reply, {:error, reason}, seller_state}
    end
  end

  @impl true
  def handle_call({:deliver_party_invite, invite}, _from, state) do
    PartyHandler.handle_invite_delivery(invite, state)
  end

  @impl true
  def handle_call({:script_apply, op}, _from, state) do
    {reply, new_state} = ScriptEffectHandler.apply_op(op, state)

    case reply do
      {:error, _reason} ->
        {:reply, reply, new_state}

      _ok_reply ->
        {:reply, reply, update_game_state(new_state, new_state.game_state)}
    end
  end

  @impl true
  def terminate(
        _reason,
        %{game_state: game_state, connection_monitor_ref: connection_monitor_ref} = state
      ) do
    Process.demonitor(connection_monitor_ref, [:flush])

    # Tear down an open vending shop so the registry entry + board don't leak;
    # a no-op when this session isn't vending.
    VendingHandler.close_shop(state, :disconnected)

    # Save final position to database (synchronous to ensure it's persisted)
    CharacterPersistence.update_position(
      game_state.character_id,
      game_state.x,
      game_state.y,
      game_state.map_name
    )

    if game_state.party_id > 0 do
      PartyManager.set_online(game_state.party_id, game_state.character_id, false)
    end

    WarpHandler.leave_current_map(game_state, DespawnReason.logged_out())

    # Clean up player data (only if this process still owns the registry entry)
    UnitRegistry.unregister_player(game_state.character_id, self())

    :ok
  end

  # Rolls the slain mob's drop table from the killer's session (the only place
  # holding both the table and the killer's stats) and places any results as
  # ground items through the map coordinator. Legacy payloads without a drop
  # table fall through to the no-op clause.
  defp maybe_drop_items(%{drops: drops, mob_level: mob_level, map: map, x: x, y: y}, state) do
    stats = state.game_state.stats
    luk = Stats.get_effective_stat(stats, :luk)
    base_level = stats.progression.base_level

    case DropCalculator.roll(drops, luk, base_level, mob_level, map, x, y) do
      [] -> :ok
      rolled -> Coordinator.drop_items(map, rolled, x, y)
    end
  end

  defp maybe_drop_items(_payload, _state), do: :ok

  defp update_game_state(state, new_game_state) do
    UnitRegistry.update_unit_state(:player, new_game_state.character_id, new_game_state)

    %{state | game_state: new_game_state}
  end

  defp register_player(%PlayerState{} = game_state),
    do: UnitRegistry.register_player(game_state, self())

  defp subscribe_party(%{game_state: %{party_id: 0}} = state), do: state

  defp subscribe_party(%{game_state: %{party_id: party_id, character_id: char_id}} = state) do
    with {:ok, _party_state} <- PartyManager.ensure_started(party_id),
         {:ok, party_state} <- PartyManager.set_online(party_id, char_id, true) do
      PubSub.subscribe(Aesir.PubSub, "party:#{party_id}")
      MessageRouter.send_to(state.connection_pid, build_party_info(party_state))
      state
    else
      {:error, _reason} -> reconcile_missing_party(state)
    end
  end

  # Kicked-while-offline reconciliation: the party row is gone, or the
  # character no longer appears in a still-live party's member list. Silent
  # per design ("Login/logout") -- no ack, just a fire-and-forget persist.
  defp reconcile_missing_party(%{game_state: game_state} = state) do
    CharacterPersistence.update_character(game_state.character_id, %{party_id: 0}, async: true)
    update_game_state(state, %{game_state | party_id: 0})
  end

  defp build_party_info(%PartyState{} = party_state) do
    %PartyInfo{
      party_id: party_state.party_id,
      name: party_state.name,
      leader_char_id: party_state.leader_char_id,
      exp_share: party_state.exp_share,
      members:
        Enum.map(party_state.members, fn {_char_id, member} ->
          %PartyMember{
            char_id: member.char_id,
            name: member.name,
            base_level: member.base_level,
            online: member.online,
            map: member.map_name || ""
          }
        end)
    }
  end

  defp sex_to_int("F"), do: 0
  defp sex_to_int("M"), do: 1
  defp sex_to_int(_), do: 1

  defp send_player_spawn_packet(connection_pid, game_state) do
    packet = build_unit_spawn(game_state)
    MessageRouter.send_to(connection_pid, packet)
  end

  defp maybe_send_vending_board(connection_pid, char_id) do
    case VendingRegistry.get(char_id) do
      {:ok, %{title: title}} ->
        MessageRouter.send_to(connection_pid, %VendingBoardShown{unit_id: char_id, title: title})

      :error ->
        :ok
    end
  end

  defp send_active_icons(unit_type, subject_id, observer_id) do
    unit_type
    |> StatusDisplay.active_icons(subject_id)
    |> Enum.each(&Broadcast.to_player(observer_id, &1))
  end

  defp build_unit_spawn(game_state) do
    %{
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue
    } =
      StatusDisplay.spawn_state(:player, game_state.character_id)

    appearance = Appearance.spawn_fields(game_state.stats.equipment)

    %UnitSpawn{
      object_type: ObjectType.pc(),
      aid: game_state.account_id,
      gid: game_state.character_id,
      speed: game_state.walk_speed,
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue,
      job: game_state.stats.progression.job_id,
      head: game_state.hair,
      weapon: appearance.weapon,
      shield: appearance.shield,
      accessory: appearance.accessory,
      accessory2: appearance.accessory2,
      accessory3: appearance.accessory3,
      head_palette: game_state.hair_color,
      body_palette: game_state.clothes_color,
      head_dir: 0,
      robe: appearance.robe,
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
