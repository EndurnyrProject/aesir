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
  alias Aesir.Net.SkillUnitDespawn
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcOwnerEventHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PartyHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VisibilityHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PartySync
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
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

  @spec apply_walk_delay(pid(), non_neg_integer()) :: :ok
  def apply_walk_delay(pid, duration), do: GenServer.cast(pid, {:apply_walk_delay, duration})

  @doc """
  Drains SP from this player (fire-and-forget), clamping at zero.

  Used by SP-costing status effects such as Energy Coat.
  """
  @spec consume_sp(pid(), non_neg_integer()) :: :ok
  def consume_sp(pid, amount) do
    GenServer.cast(pid, {:consume_sp, amount})
  end

  @doc """
  Attempts to deduct SP synchronously without allowing an insufficient balance
  to underflow.
  """
  @spec try_consume_sp(pid(), non_neg_integer()) ::
          :ok | {:error, :insufficient_sp | :target_unavailable}
  def try_consume_sp(pid, amount), do: call_session(pid, {:try_consume_sp, amount})

  @doc """
  Revives this target session in place at a percentage of its maximum HP.
  """
  @spec resurrect(pid(), integer(), pos_integer()) ::
          :ok
          | {:error,
             :stale_target | :invalid_hp_percent | :source_unavailable | :target_unavailable}
  def resurrect(pid, source_id, hp_percent) do
    call_session(pid, {:resurrect, source_id, hp_percent})
  end

  defp call_session(pid, message) do
    if Process.alive?(pid) do
      try do
        GenServer.call(pid, message)
      catch
        :exit, _reason -> {:error, :target_unavailable}
      end
    else
      {:error, :target_unavailable}
    end
  end

  @doc """
  Restores SP to this player (fire-and-forget), clamping at max SP.

  Used by SP-gaining status effects such as Magic Rod.
  """
  @spec restore_sp(pid(), non_neg_integer()) :: :ok
  def restore_sp(pid, amount) do
    GenServer.cast(pid, {:restore_sp, amount})
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
  Delivers a pending guild invite to this player's session: stores it, sends the
  `GuildInviteNotify`, and arms its 30s expiry timer. Rejects a second invite
  while one is already pending and unexpired. Mirrors `deliver_party_invite/2`.
  """
  @spec deliver_guild_invite(pid(), map()) :: :ok | {:error, :invite_pending}
  def deliver_guild_invite(pid, invite) do
    GenServer.call(pid, {:deliver_guild_invite, invite})
  end

  @doc "Notifies this player that `about_char_id` entered their view range."
  @spec notify_entered_view(pid(), non_neg_integer()) :: :ok
  def notify_entered_view(pid, about_char_id) do
    GenServer.cast(pid, {:player_entered_view, about_char_id})
  end

  @doc "Warps this player to `{x, y}` on `map_name`."
  @spec warp(pid(), String.t(), integer(), integer()) :: :ok
  def warp(pid, map_name, x, y) do
    GenServer.cast(pid, {:warp, map_name, x, y})
  end

  @doc "Gives `amount` of `item_def` to this player's inventory."
  @spec give_item(pid(), ItemDefinition.t(), pos_integer()) :: :ok
  def give_item(pid, item_def, amount) do
    GenServer.cast(pid, {:give_item, item_def, amount})
  end

  @doc "Repairs every broken item in this player's inventory at no cost."
  @spec repair_all(pid()) :: :ok
  def repair_all(pid) do
    GenServer.cast(pid, :repair_all)
  end

  @doc "Applies a script DSL state-mutating `op` through the single-writer session."
  @spec script_apply(pid(), ScriptEffectHandler.op()) :: ScriptEffectHandler.reply()
  def script_apply(pid, op) do
    GenServer.call(pid, {:script_apply, op})
  end

  @doc "Forwards a decoded client `message` to this player's session for routing."
  @spec deliver_message(pid(), struct()) :: :ok
  def deliver_message(pid, message) do
    send(pid, {:message, message})
    :ok
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
      interaction_lock: nil,
      pending_skill_menu: nil
    }

    register_player(final_game_state)

    # Restore a mounted cart: load its rows, set the tier, and re-apply
    # SC_PUSHCART so the sprite folds into the spawn effect_state and the
    # walk-speed penalty is recomputed. Runs after registration so the
    # status apply can resolve the unit's entity info.
    state = CartHandler.load_on_spawn(character, state)

    # Restore the statuses persisted at logout (rAthena sc_data), consuming
    # the saved rows. Runs after registration for the same reason as the cart.
    state = StatusPersistence.restore_on_spawn(state)

    # Load the quest log (rAthena quest table). Non-consuming: the rows stay
    # the durable source of truth and are write-through updated on mutation.
    state = QuestPersistence.load_on_spawn(state)

    # Subscribe to this player's event topic. Kill rewards and other
    # player-directed domain events arrive here, keeping emitters
    # (mobs, etc.) decoupled from the player session.
    PubSub.subscribe(Aesir.PubSub, "player:#{character.id}")

    # Join the party's presence topic and send the initial snapshot when the
    # character is party'd. A missing party row or a live party that no
    # longer lists this character (kicked while offline) silently resets
    # `party_id` back to 0 instead of subscribing (design "Login/logout").
    state = SocialHandler.subscribe_party(state)

    # Subscribe to the guild topic and push an online presence snapshot for a
    # character already in a guild at login (mirrors `subscribe_party`); a no-op
    # when the player has no guild.
    state = SocialHandler.subscribe_guild(state)

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

  @impl true
  def handle_info({:skill_deferred, module, payload}, %{game_state: game_state} = state) do
    if function_exported?(module, :deferred, 2) do
      _ = module.deferred(payload, game_state)
    else
      Logger.error(
        "PlayerSession dropped deferred skill effect: #{inspect(module)} does not implement deferred/2"
      )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:mob_killed, payload}, state) do
    LootHandler.mob_killed(payload, state)
  end

  @impl true
  def handle_info({:quest_kill, mob_id}, state) do
    LootHandler.quest_kill(mob_id, state)
  end

  # A contributing attacker's final damage-based EXP grant for a mob kill
  # (`Unit.Mob.KillExp.distribute/6`, design "Damage-based EXP share"),
  # already scaled by the damage/bonus/penalty (or party pool/bonus/penalty)
  # math. Only the killed mob's race is still ours to apply, through this
  # session's own per-race equipment EXP bonus.
  @impl true
  def handle_info({:mob_kill_exp, base, job, mob_race}, state) do
    ExperienceHandler.handle_gain_exp(base, job, mob_race, state)
  end

  @impl true
  def handle_info({:social, msg}, state) do
    SocialHandler.info(msg, state)
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
  def handle_info({:reset_stats}, state) do
    {:ok, new_state} = ProgressionHandler.reset_stats(state)
    {:noreply, new_state}
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
  def handle_info({:player_despawned, char_id}, state) do
    VisibilityHandler.despawned(char_id, state)
  end

  # Unknown messages must not crash a live player session.
  def handle_info(message, %{game_state: game_state} = state) do
    Logger.error(
      "PlayerSession #{game_state.character_id} received unknown info: #{inspect(message)}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:player_entered_view, other_char_id}, state) do
    VisibilityHandler.entered_view(other_char_id, state)
  end

  @impl true
  def handle_cast({:player_left_view, other_char_id, _other_account_id}, state) do
    VisibilityHandler.left_view(other_char_id, state)
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
    WarpHandler.handle_warp(map_name, x, y, state)
  end

  @impl true
  def handle_cast({:give_item, item_def, amount}, state) do
    InventoryManager.handle_give_item_cast(item_def, amount, state)
  end

  @impl true
  def handle_cast({:break_equip, slot}, state) do
    InventoryManager.handle_break_equip(slot, state)
  end

  @impl true
  def handle_cast(:repair_all, state) do
    InventoryManager.handle_repair_all(state)
  end

  # A bolt SA_AUTOSPELL armed, procced by one of this player's weapon hits. Cast
  # to self() by the combat path from inside this very session, so it runs after
  # the triggering hit has fully committed, on state this session already wrote.
  @impl true
  def handle_cast({:auto_cast, skill_id, level, target}, state) do
    SkillHandler.handle_auto_cast(state, skill_id, level, target)
  end

  @impl true
  def handle_cast({:apply_damage, damage, attacker_id}, state) do
    HealthHandler.apply_damage(damage, attacker_id, state)
  end

  def handle_cast({:apply_walk_delay, duration}, %{game_state: game_state} = state) do
    delayed =
      PlayerState.apply_walk_delay(game_state, duration, System.monotonic_time(:millisecond))

    MovementHandler.handle_force_stop_movement(%{state | game_state: delayed})
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
  def handle_cast({:restore_sp, amount}, state) do
    HealthHandler.restore_sp(amount, state)
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
        {:send_packet, %SkillUnitDespawn{group_id: group_id} = packet},
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    if connection_pid do
      MessageRouter.send_to(connection_pid, packet)
    end

    game_state =
      if SkillUnitStorage.get(group_id) do
        game_state
      else
        %{
          game_state
          | visible_skill_units: MapSet.delete(game_state.visible_skill_units, group_id)
        }
      end

    {:noreply, update_game_state(state, game_state)}
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

  # Unknown messages must not crash a live player session.
  def handle_cast(message, %{game_state: game_state} = state) do
    Logger.error(
      "PlayerSession #{game_state.character_id} received unknown cast: #{inspect(message)}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:try_consume_sp, amount}, _from, state) do
    HealthHandler.try_consume_sp(amount, state)
  end

  @impl true
  def handle_call({:resurrect, source_id, hp_percent}, _from, state) do
    HealthHandler.handle_resurrect(source_id, hp_percent, state)
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
  def handle_call({:deliver_guild_invite, invite}, _from, state) do
    GuildHandler.handle_invite_delivery(invite, state)
  end

  @impl true
  def handle_call({:script_apply, op}, _from, state) do
    ScriptEffectHandler.handle_script_apply(op, state)
  end

  @impl true
  def terminate(
        reason,
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
      PartySync.sync(game_state, online: false)
    end

    if game_state.guild_id > 0 do
      GuildSync.sync(game_state, online: false)
    end

    WarpHandler.leave_current_map(game_state, DespawnReason.logged_out())

    unless game_state.action_state == :dead do
      Lifecycle.publish_departure(
        :player,
        game_state.character_id,
        game_state.map_name,
        departure_reason(reason)
      )
    end

    # Persist the survivable statuses, then drop them all from StatusStorage:
    # leaving entries behind for an unregistered unit would orphan them and
    # the tick manager would have to garbage-collect them.
    StatusPersistence.save_statuses(game_state.character_id)
    StatusStorage.clear_unit_statuses(:player, game_state.character_id)

    # Clean up player data (only if this process still owns the registry entry)
    UnitRegistry.unregister_player(game_state.character_id, self())

    :ok
  end

  defp departure_reason(:normal), do: :disconnect
  defp departure_reason(_reason), do: :termination

  defp update_game_state(state, new_game_state) do
    StateCommit.commit(state, new_game_state)
  end

  defp register_player(%PlayerState{} = game_state),
    do: UnitRegistry.register_player(game_state, self())
end
