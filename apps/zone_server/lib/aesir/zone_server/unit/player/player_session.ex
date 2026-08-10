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
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler, as: HomunculusCommandHandler
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.CombatActionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipRegenHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcOwnerEventHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PartyHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PickupHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritExchangeHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VisibilityHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PartySync
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending
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
    GenServer.cast(pid, {:unit, {:apply_damage, damage, attacker_id}})
  end

  @doc """
  Notifies this player that a skill hit landed, so plagiarism recording can run.
  Separate from `apply_damage/3` to keep the damage path's contract unchanged.
  """
  def record_skill_hit(pid, skill_id, skill_level) do
    GenServer.cast(pid, {:unit, {:record_skill_hit, skill_id, skill_level}})
  end

  @spec apply_walk_delay(pid(), non_neg_integer()) :: :ok
  def apply_walk_delay(pid, duration),
    do: GenServer.cast(pid, {:movement, {:apply_walk_delay, duration}})

  @doc """
  Drains SP from this player (fire-and-forget), clamping at zero.

  Used by SP-costing status effects such as Energy Coat. Shares the converged
  `{:unit, {:drain_sp, _}}` tag with `MobSession.zap_sp/2`.
  """
  @spec consume_sp(pid(), non_neg_integer()) :: :ok
  def consume_sp(pid, amount) do
    GenServer.cast(pid, {:unit, {:drain_sp, amount}})
  end

  @spec summon_spirit_sphere(pid(), pos_integer(), pos_integer()) :: :ok
  def summon_spirit_sphere(pid, duration, cap \\ 5) do
    GenServer.cast(pid, {:summon_spirit_sphere, duration, cap})
  end

  @spec consume_spirit_spheres(pid(), pos_integer()) :: :ok
  def consume_spirit_spheres(pid, count) do
    GenServer.cast(pid, {:consume_spirit_spheres, count})
  end

  @doc """
  Attempts to deduct SP synchronously without allowing an insufficient balance
  to underflow.
  """
  @spec try_consume_sp(pid(), non_neg_integer()) ::
          :ok | {:error, :insufficient_sp | :target_unavailable}
  def try_consume_sp(pid, amount), do: call_session(pid, {:unit, {:try_consume_sp, amount}})

  @doc """
  Revives this target session in place at a percentage of its maximum HP.
  """
  @spec resurrect(pid(), integer(), pos_integer()) ::
          :ok
          | {:error,
             :stale_target | :invalid_hp_percent | :source_unavailable | :target_unavailable}
  def resurrect(pid, source_id, hp_percent) do
    call_session(pid, {:unit, {:resurrect, source_id, hp_percent}})
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
    GenServer.cast(pid, {:unit, {:restore_sp, amount}})
  end

  @doc """
  Runs an attached NPC event for this player session on `module`'s `gid`
  (currently only `Map.Coordinator`'s OnMyMobDead owner-event dispatch, fired
  when a mob tagged with `event:` dies to this player).
  """
  @spec run_attached_event(pid(), module(), non_neg_integer(), String.t()) :: :ok
  def run_attached_event(pid, module, gid, label) do
    GenServer.cast(pid, {:npc, {:run_attached_event, module, gid, label}})
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
    GenServer.cast(pid, {:movement, :force_stop_movement})
  end

  @doc """
  Sends a status update to this player.
  Automatically chooses between ZC_PAR_CHANGE and ZC_LONGPAR_CHANGE based on value size.
  """
  def send_status_update(pid, param_id, value) do
    GenServer.cast(pid, {:stats, {:send_status_update, param_id, value}})
  end

  @doc """
  Sends multiple status updates to this player efficiently.
  """
  def send_status_updates(pid, status_map) when is_map(status_map) do
    GenServer.cast(pid, {:stats, {:send_status_updates, status_map}})
  end

  @doc """
  Updates a base stat and recalculates derived stats.
  """
  def update_base_stat(pid, stat_name, new_value)
      when stat_name in [:str, :agi, :vit, :int, :dex, :luk] do
    GenServer.call(pid, {:stats, {:update_base_stat, stat_name, new_value}})
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
    GenServer.call(pid, {:stats, :recalculate})
  end

  def recalculate_stats(pid, false) do
    GenServer.cast(pid, {:stats, :recalculate})
    :ok
  end

  @doc """
  Gets the current Stats struct.
  """
  def get_current_stats(pid) do
    GenServer.call(pid, {:stats, :get_current_stats})
  end

  @doc """
  Adds base levels to this player (e.g. `@baselevelup`), clamped to the job's
  max base level.
  """
  @spec add_base_level(pid(), pos_integer()) :: :ok
  def add_base_level(pid, amount) do
    GenServer.cast(pid, {:progression, {:add_base_level, amount}})
  end

  @doc """
  Adds job levels to this player (e.g. `@joblevelup`), clamped to the job's
  max job level.
  """
  @spec add_job_level(pid(), pos_integer()) :: :ok
  def add_job_level(pid, amount) do
    GenServer.cast(pid, {:progression, {:add_job_level, amount}})
  end

  @doc """
  Toggles this player's Peco-Peco mount for the GM `@mount` testing tool:
  dismounts if mounted, otherwise force-mounts bypassing the `KN_RIDING`
  learned gate (the alive/already-mounted gates still apply).
  """
  @spec gm_toggle_mount(pid()) :: :ok
  def gm_toggle_mount(pid) do
    GenServer.cast(pid, {:mount, :gm_toggle})
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
    GenServer.call(pid, {:status, {:apply_status, status_id, status_params}})
  end

  @doc """
  Removes a status effect from the player.
  Delegates to the StatusEffect.Interpreter and triggers stats recalculation.
  """
  def remove_status(pid, status_id) do
    GenServer.call(pid, {:status, {:remove_status, status_id}})
  end

  @doc """
  Gets all active status effects for the player.
  """
  def get_active_statuses(pid) do
    GenServer.call(pid, {:status, :get_active_statuses})
  end

  @doc """
  Checks if a player has a specific status effect.
  """
  def has_status?(pid, status_id) do
    GenServer.call(pid, {:status, {:has_status, status_id}})
  end

  @doc """
  Delivers a pending party invite to this player's session: stores it, sends
  the `PartyInviteNotify`, and arms its 30s expiry timer. Rejects a second
  invite while one is already pending and unexpired.
  """
  @spec deliver_party_invite(pid(), map()) :: :ok | {:error, :invite_pending}
  def deliver_party_invite(pid, invite) do
    GenServer.call(pid, {:social, {:deliver_party_invite, invite}})
  end

  @doc """
  Delivers a pending guild invite to this player's session: stores it, sends the
  `GuildInviteNotify`, and arms its 30s expiry timer. Rejects a second invite
  while one is already pending and unexpired. Mirrors `deliver_party_invite/2`.
  """
  @spec deliver_guild_invite(pid(), map()) :: :ok | {:error, :invite_pending}
  def deliver_guild_invite(pid, invite) do
    GenServer.call(pid, {:social, {:deliver_guild_invite, invite}})
  end

  @doc "Notifies this player that `about_char_id` entered their view range."
  @spec notify_entered_view(pid(), non_neg_integer()) :: :ok
  def notify_entered_view(pid, about_char_id) do
    GenServer.cast(pid, {:visibility, {:player_entered_view, about_char_id}})
  end

  @doc """
  Notifies this player that `about_char_id` (account `about_account_id`) left
  their view range.
  """
  @spec notify_left_view(pid(), non_neg_integer(), non_neg_integer()) :: :ok
  def notify_left_view(pid, about_char_id, about_account_id) do
    GenServer.cast(pid, {:visibility, {:player_left_view, about_char_id, about_account_id}})
  end

  @doc "Grants mob-kill base EXP to this owner's exact active Homunculus."
  @spec gain_homunculus_exp(pid(), pos_integer(), non_neg_integer(), String.t()) :: :ok
  def gain_homunculus_exp(owner_pid, gid, base_exp, mob_map) do
    GenServer.cast(owner_pid, {:homunculus, {:gain_exp, gid, base_exp, mob_map}})
  end

  @doc "Notifies this player that a Homunculus entered their view range."
  @spec notify_homunculus_entered_view(pid(), pos_integer()) :: :ok
  def notify_homunculus_entered_view(pid, gid) do
    GenServer.cast(pid, {:visibility, {:homunculus_entered_view, gid}})
  end

  @doc "Notifies this player that a Homunculus left their view range."
  @spec notify_homunculus_left_view(pid(), pos_integer()) :: :ok
  def notify_homunculus_left_view(pid, gid) do
    GenServer.cast(pid, {:visibility, {:homunculus_left_view, gid}})
  end

  @doc "Notifies this player that a visible Homunculus died."
  @spec notify_homunculus_died(pid(), pos_integer()) :: :ok
  def notify_homunculus_died(pid, gid) do
    GenServer.cast(pid, {:visibility, {:homunculus_died, gid}})
  end

  @doc "Warps this player to `{x, y}` on `map_name`."
  @spec warp(pid(), String.t(), integer(), integer()) :: :ok
  def warp(pid, map_name, x, y) do
    GenServer.cast(pid, {:movement, {:warp, map_name, x, y}})
  end

  @doc "Gives `amount` of `item_def` to this player's inventory."
  @spec give_item(pid(), ItemDefinition.t(), pos_integer()) :: :ok
  def give_item(pid, item_def, amount) do
    GenServer.cast(pid, {:inventory, {:give_item, item_def, amount}})
  end

  @spec give_item(pid(), ItemDefinition.t(), pos_integer(), keyword()) :: :ok
  def give_item(pid, item_def, amount, opts) do
    GenServer.cast(pid, {:inventory, {:give_item, item_def, amount, opts}})
  end

  @doc """
  Breaks the equipment worn in `slot` on this player: a natural break on the
  attacker's own weapon, or (once PvP enables the enemy-break path) a landed
  break roll on the target.
  """
  @spec break_equip(pid(), atom()) :: :ok
  def break_equip(pid, slot) do
    GenServer.cast(pid, {:inventory, {:break_equip, slot}})
  end

  @doc "Force-unequips `slot` and applies its matching Divest status."
  @spec strip_equip(pid(), atom(), keyword()) :: :ok
  def strip_equip(pid, slot, status_opts) do
    GenServer.cast(pid, {:equipment, {:strip, slot, status_opts}})
  end

  @doc "Repairs one broken inventory row through its owning player session."
  @spec repair_item(pid(), non_neg_integer()) :: :ok | {:error, term()}
  def repair_item(pid, index) do
    call_session(pid, {:inventory, {:repair_item, index}})
  end

  @doc "Repairs every broken item in this player's inventory at no cost."
  @spec repair_all(pid()) :: :ok
  def repair_all(pid) do
    GenServer.cast(pid, {:inventory, :repair_all})
  end

  @doc "Applies a script DSL state-mutating `op` through the single-writer session."
  @spec script_apply(pid(), ScriptEffectHandler.op()) :: ScriptEffectHandler.reply()
  def script_apply(pid, op) do
    GenServer.call(pid, {:npc, {:script_apply, op}})
  end

  @doc """
  Runs a vending purchase against this seller session: the transactional
  authority for its own cart, zeny and shop. Called from the buyer's
  `VendingHandler.handle_purchase_request/3` with the buyer's fresh snapshot,
  parked as a `call` on the seller.
  """
  @spec vending_purchase(
          pid(),
          integer(),
          Inventory.t(),
          non_neg_integer(),
          Stats.t(),
          String.t(),
          [Vending.buy_line()]
        ) :: {:ok, VendingHandler.buyer_delta()} | {:error, term()}
  def vending_purchase(
        pid,
        buyer_char_id,
        buyer_inventory,
        buyer_zeny,
        buyer_stats,
        buyer_name,
        buy_lines
      ) do
    GenServer.call(
      pid,
      {:vending,
       {:vending_purchase, buyer_char_id, buyer_inventory, buyer_zeny, buyer_stats, buyer_name,
        buy_lines}}
    )
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
    client_capabilities = get_client_capabilities(args)
    game_state = PlayerState.new(character)

    {:ok, updated_game_state} = InventoryManager.load_character_inventory(character, game_state)
    final_game_state = PlayerState.set_process_pid(updated_game_state, self())

    # Monitor the connection process to detect crashes
    connection_monitor_ref = Process.monitor(connection_pid)

    state = %SessionState{
      game_state: final_game_state,
      connection_pid: connection_pid,
      connection_monitor_ref: connection_monitor_ref,
      client_capabilities: client_capabilities
    }

    {:ok, state} = HomunculusCommandHandler.restore(state, loaded_homunculus(character))

    register_player(final_game_state)

    # Restore a mounted cart: load its rows, set the tier, and re-apply
    # SC_PUSHCART so the sprite folds into the spawn effect_state and the
    # walk-speed penalty is recomputed. Runs after registration so the
    # status apply can resolve the unit's entity info.
    state = CartHandler.load_on_spawn(character, state)

    # Restore a mounted Peco-Peco: re-apply SC_RIDING from the persisted
    # option bit so the sprite and speed/ASPD modifiers come back on spawn.
    state = MountHandler.load_on_spawn(character, state)

    # Restore an equipped Falcon: re-apply SC_FALCON from the persisted option
    # bit so the sprite folds into the spawn effect_state. A stale bit without
    # Falconry Mastery is cleared and persisted instead of being mirrored.
    state = FalconHandler.load_on_spawn(character, state)

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

    case HomunculusCommandHandler.spawned(state) do
      {:noreply, state} ->
        # Check initial visibility for players and mobs
        updated_game_state = MovementHandler.handle_visibility_update(state.game_state)

        # After initial spawn, transition to standing state
        # This happens after a short delay to ensure spawn packets are processed
        Process.send_after(self(), :complete_spawn, 100)

        # Start the recurring natural-heal regen tick.
        Process.send_after(self(), :natural_heal_tick, @natural_heal_interval)

        {:noreply, update_game_state(state, updated_game_state)}

      {:stop, reason, state} ->
        {:stop, reason, state}
    end
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
    state = update_game_state(state, updated_game_state)
    HomunculusCommandHandler.entered_after_warp(state)
  end

  @impl true
  def handle_info(:complete_spawn, %{game_state: game_state} = state) do
    updated_game_state = PlayerState.mark_spawn_complete(game_state)
    {:noreply, update_game_state(state, updated_game_state)}
  end

  @impl true
  def handle_info(:natural_heal_tick, state) do
    Process.send_after(self(), :natural_heal_tick, @natural_heal_interval)
    {:noreply, state} = EquipRegenHandler.handle_tick(state, @natural_heal_interval)
    NaturalHealHandler.handle_tick(state, @natural_heal_interval)
  end

  # Movement: the self-armed walk tick, and the cross-domain movement_completed
  # orchestrator that routes arrival to whichever domain the player's action
  # state and movement intent say it serves (combat, skill, pickup, or a plain
  # walk) - kept here rather than in a handler since the routing itself spans
  # domains.
  @impl true
  def handle_info({:movement, :movement_tick}, state) do
    MovementHandler.handle_movement_tick(state)
  end

  def handle_info({:movement, :movement_completed}, %{game_state: game_state} = state) do
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
  def handle_info({:timeout, ref, {:homunculus, event}}, state) do
    HomunculusCommandHandler.info(event, ref, state)
  end

  # Combat: cross-unit heal broadcast on this player's topic, and the
  # self-armed auto-attack loop tick.
  @impl true
  def handle_info({:combat, {:apply_heal, amount, source_id}}, state) do
    HealthHandler.apply_heal(amount, source_id, state)
  end

  @impl true
  def handle_info({:combat, {:restore_sp, amount}}, state) do
    HealthHandler.restore_sp(amount, state)
  end

  @impl true
  def handle_info({:combat, {:auto_attack, target_id}}, state) do
    CombatActionHandler.handle_auto_attack(state, target_id)
  end

  @impl true
  def handle_info({:attack_intent, {_target_type, target_id}}, state) do
    CombatActionHandler.handle_attack_request(state, target_id, 0)
  end

  # Combat: the combo-window timeout that expires an unconsumed Monk combo.
  @impl true
  def handle_info({:combo_timeout, generation}, state) do
    CombatActionHandler.handle_combo_timeout(state, generation)
  end

  # Skill: the cast-timer resolution, and the generic deferred-effect seam
  # (`Skill.defer/3`) that runs `module.deferred/2` on the caster's own state.
  @impl true
  def handle_info({:skill, {:cast_complete, token}}, state) do
    SkillHandler.handle_cast_complete(state, token)
  end

  @impl true
  def handle_info({:skill, {:deferred, module, payload}}, %{game_state: game_state} = state) do
    if function_exported?(module, :deferred, 2) do
      _ = module.deferred(payload, game_state)
    else
      Logger.error(
        "PlayerSession dropped deferred skill effect: #{inspect(module)} does not implement deferred/2"
      )
    end

    {:noreply, state}
  end

  # Progression: job change and stat/skill resets (ProgressionHandler), plus
  # each contributing attacker's final damage-based EXP grant for a mob kill
  # (already scaled by the damage/bonus/penalty math; only the killed mob's
  # race and class are still ours to apply, through this session's equipment
  # EXP bonuses).
  @impl true
  def handle_info({:progression, {:mob_kill_exp, base, job, mob_race, mob_class}}, state) do
    ExperienceHandler.handle_gain_exp(base, job, mob_race, mob_class, state)
  end

  @impl true
  def handle_info({:progression, msg}, state) do
    ProgressionHandler.info(msg, state)
  end

  # Stats: recompute cached stats after a status change. `{:stats, :recalculate}`
  # comes from StatusTickManager; the bare `:recalculate_stats` comes from the
  # status-effect interpreter and runs the richer reconciliation that settles
  # status-driven side effects (Fury / Mental Strength and friends).
  @impl true
  def handle_info({:stats, :recalculate}, state) do
    StatsManager.handle_recalculate_stats(state)
  end

  @impl true
  def handle_info(:recalculate_stats, state) do
    {:noreply, StatusManager.recalculate_after_status_change(state)}
  end

  # Loot: drop rolling and hunting-quest kill credit.
  @impl true
  def handle_info({:loot, msg}, state) do
    LootHandler.info(msg, state)
  end

  # Social: party/guild presence lifecycle.
  @impl true
  def handle_info({:social, msg}, state) do
    SocialHandler.info(msg, state)
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
  def handle_info({:spirit_sphere_expire, generation}, state) do
    SpiritSphereHandler.expire(state, generation)
  end

  @impl true
  def handle_info({:deferred_skill_timeout, token}, state) do
    SkillHandler.handle_deferred_timeout(state, token)
  end

  @impl true
  def handle_info({:skill_text_input_timeout, request_id}, state) do
    SkillTextInputHandler.handle_timeout(state, request_id)
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

  # Unknown messages must not crash a live player session.
  def handle_info(message, %{game_state: game_state} = state) do
    Logger.error(
      "PlayerSession #{game_state.character_id} received unknown info: #{inspect(message)}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:homunculus, command}, state) do
    HomunculusCommandHandler.cast(command, state)
  end

  # Visibility: another player's session directly casting to this one as it
  # enters or leaves view range (point-to-point, not PubSub - MovementHandler
  # resolves the target session and casts to it directly).
  @impl true
  def handle_cast({:visibility, {:player_entered_view, other_char_id}}, state) do
    VisibilityHandler.entered_view(other_char_id, state)
  end

  @impl true
  def handle_cast({:visibility, {:player_left_view, other_char_id, _other_account_id}}, state) do
    VisibilityHandler.left_view(other_char_id, state)
  end

  @impl true
  def handle_cast({:visibility, {:homunculus_entered_view, gid}}, state) do
    VisibilityHandler.homunculus_entered_view(gid, state)
  end

  @impl true
  def handle_cast({:visibility, {:homunculus_left_view, gid}}, state) do
    VisibilityHandler.homunculus_left_view(gid, state)
  end

  @impl true
  def handle_cast({:visibility, {:homunculus_died, gid}}, state) do
    VisibilityHandler.homunculus_died(gid, state)
  end

  # Movement: the knockback landing delegates to MovementHandler (stop +
  # position-set, same shape as the mob path). The walk-delay cast (post-hit
  # slow) applies its bookkeeping here then delegates its stop to the same
  # force-stop path as the forced-stop cast (skill/stun interrupts) -
  # deliberately not the knockback stop, since a player's stop is conditional
  # and sends a client-visible MoveStop packet. The warp cast (on-touch warp
  # NPCs, AL_WARP, GM @warp) delegates too.
  @impl true
  def handle_cast({:movement, {:displace, expected_x, expected_y, map_name, x, y}}, state) do
    MovementHandler.handle_displacement(state, expected_x, expected_y, map_name, x, y)
  end

  @impl true
  def handle_cast({:movement, :force_stop_movement}, state) do
    MovementHandler.handle_force_stop_movement(state)
  end

  @impl true
  def handle_cast({:movement, {:apply_walk_delay, duration}}, %{game_state: game_state} = state) do
    delayed =
      PlayerState.apply_walk_delay(game_state, duration, System.monotonic_time(:millisecond))

    MovementHandler.handle_force_stop_movement(%{state | game_state: delayed})
  end

  @impl true
  def handle_cast({:movement, {:warp, map_name, x, y}}, state) do
    WarpHandler.handle_warp(map_name, x, y, state)
  end

  # Inventory: item grants (GM @item, NPC/quest rewards), and the break/repair
  # pair (natural weapon break on a swing, GM @repairall).
  @impl true
  def handle_cast({:inventory, {:give_item, item_def, amount}}, state) do
    InventoryManager.handle_give_item_cast(item_def, amount, state)
  end

  @impl true
  def handle_cast({:inventory, {:give_item, item_def, amount, opts}}, state) do
    InventoryManager.handle_give_item_cast(item_def, amount, state, opts)
  end

  @impl true
  def handle_cast({:inventory, {:break_equip, slot}}, state) do
    InventoryManager.handle_break_equip(slot, state)
  end

  @impl true
  def handle_cast({:inventory, :repair_all}, state) do
    InventoryManager.handle_repair_all(state)
  end

  @impl true
  def handle_cast({:equipment, {:strip, slot, status_opts}}, state) do
    EquipmentHandler.handle_strip(slot, status_opts, state)
  end

  # Skill: a bolt SA_AUTOSPELL armed, procced by one of this player's weapon
  # hits. Cast to self() by the combat path from inside this very session, so
  # it runs after the triggering hit has fully committed, on state this
  # session already wrote.
  @impl true
  def handle_cast({:skill, {:auto_cast, skill_id, level, target}}, state) do
    SkillHandler.handle_auto_cast(state, skill_id, level, target)
  end

  # Unit: vitals casts (damage, SP drain/restore), all handled in
  # HealthHandler. Heal stays under `:combat` - the player heal carries
  # received-heal-rate scaling that is genuinely player-only.
  @impl true
  def handle_cast({:unit, {:apply_damage, damage, attacker_id}}, state) do
    HealthHandler.apply_damage(damage, attacker_id, state)
  end

  @impl true
  def handle_cast({:unit, {:record_skill_hit, skill_id, skill_level}}, state) do
    HealthHandler.record_skill_hit(skill_id, skill_level, state)
  end

  @impl true
  def handle_cast({:unit, {:drain_sp, amount}}, state) do
    HealthHandler.consume_sp(amount, state)
  end

  @impl true
  def handle_cast({:unit, {:restore_sp, amount}}, state) do
    HealthHandler.restore_sp(amount, state)
  end

  # Progression: GM base/job level grants (`@baselevelup`/`@joblevelup`).
  @impl true
  def handle_cast({:progression, {:add_base_level, amount}}, state) do
    ProgressionHandler.handle_add_base_level(amount, state)
  end

  @impl true
  def handle_cast({:progression, {:add_job_level, amount}}, state) do
    ProgressionHandler.handle_add_job_level(amount, state)
  end

  # Mount: GM `@mount` toggle, bypassing the KN_RIDING learned gate.
  @impl true
  def handle_cast({:mount, :gm_toggle}, state) do
    if MountHandler.riding?(state) do
      MountHandler.dismount(state)
    else
      MountHandler.force_mount(state)
    end
  end

  # Skill: the spirit-sphere write path (Monk). Summon/consume timed spheres
  # route to SpiritSphereHandler, the single-writer handler for that state.
  @impl true
  def handle_cast({:summon_spirit_sphere, duration, cap}, state) do
    SpiritSphereHandler.summon(state, duration, cap)
  end

  @impl true
  def handle_cast({:consume_spirit_spheres, count}, state) do
    case SpiritSphereHandler.consume(state, count) do
      {:ok, state} -> {:noreply, state}
      {:error, :insufficient} -> {:noreply, state}
    end
  end

  # Skill: the spirit-exchange write path (Monk). Receive/absorb spirit spheres
  # and the deferred absorb result route to their handlers.
  @impl true
  def handle_cast({:receive_spirit_sphere, request}, state) do
    SpiritExchangeHandler.receive_sphere(state, request)
  end

  @impl true
  def handle_cast({:absorb_spirit_spheres, request}, state) do
    SpiritExchangeHandler.absorb_spheres(state, request)
  end

  @impl true
  def handle_cast({:spirit_absorb_result, token, target_id, count}, state) do
    SkillHandler.handle_spirit_absorb_result(state, token, target_id, count)
  end

  # NPC: the owner-event dispatch half of the two-message `:npc` domain (the
  # other, `{:script_apply, op}`, is a call - see the handle_call clauses).
  @impl true
  def handle_cast({:npc, {:run_attached_event, module, gid, label}}, state) do
    {:noreply, NpcOwnerEventHandler.run(module, gid, label, state)}
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

  # Stats: client status-sync casts and the async recalculate variant (the
  # sync call variant lives in the handle_call block below).
  @impl true
  def handle_cast({:stats, {:send_status_update, param_id, value}}, state) do
    StatsManager.handle_send_status_update(param_id, value, state)
  end

  @impl true
  def handle_cast({:stats, {:send_status_updates, status_map}}, state) do
    StatsManager.handle_send_status_updates(status_map, state)
  end

  @impl true
  def handle_cast({:stats, :recalculate}, state) do
    StatsManager.handle_recalculate_stats(state)
  end

  # Unknown messages must not crash a live player session.
  def handle_cast(message, %{game_state: game_state} = state) do
    Logger.error(
      "PlayerSession #{game_state.character_id} received unknown cast: #{inspect(message)}"
    )

    {:noreply, state}
  end

  # get_state stays bare: a ubiquitous utility call, not a domain message.
  defp get_client_capabilities(args) when is_list(args),
    do: Keyword.get(args, :client_capabilities, [])

  defp get_client_capabilities(args), do: Map.get(args, :client_capabilities, [])

  defp loaded_homunculus(%{homunculus: %Ecto.Association.NotLoaded{}}), do: nil
  defp loaded_homunculus(%{homunculus: homunculus}), do: homunculus

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:homunculus, command}, from, state) do
    HomunculusCommandHandler.call(command, from, state)
  end

  # Inventory: synchronous single-row mutations.
  @impl true
  def handle_call({:inventory, {:repair_item, index}}, _from, state) do
    InventoryManager.handle_repair_item(index, state)
  end

  # Unit: vitals calls (SP debit, resurrect).
  @impl true
  def handle_call({:unit, {:try_consume_sp, amount}}, _from, state) do
    HealthHandler.try_consume_sp(amount, state)
  end

  @impl true
  def handle_call({:unit, {:resurrect, source_id, hp_percent}}, _from, state) do
    HealthHandler.handle_resurrect(source_id, hp_percent, state)
  end

  # Stats: the synchronous stat calls (the async cast variants live in the
  # handle_cast block above).
  @impl true
  def handle_call({:stats, {:update_base_stat, stat_name, new_value}}, _from, state) do
    StatsManager.handle_update_base_stat(stat_name, new_value, state)
  end

  @impl true
  def handle_call({:stats, :recalculate}, _from, state) do
    StatsManager.handle_sync_recalculate_stats(state)
  end

  @impl true
  def handle_call({:stats, :get_current_stats}, _from, state) do
    StatsManager.handle_get_current_stats(state)
  end

  # Status: apply/remove/query status effects.
  @impl true
  def handle_call({:status, {:apply_status, status_id, status_params}}, _from, state) do
    StatusManager.handle_apply_status(status_id, status_params, state)
  end

  @impl true
  def handle_call({:status, {:remove_status, status_id}}, _from, state) do
    StatusManager.handle_remove_status(status_id, state)
  end

  @impl true
  def handle_call({:status, :get_active_statuses}, _from, state) do
    StatusManager.handle_get_active_statuses(state)
  end

  @impl true
  def handle_call({:status, {:has_status, status_id}}, _from, state) do
    StatusManager.handle_has_status(status_id, state)
  end

  # Vending: the seller-authority buy seam. A buyer session (parked in its own
  # call, via `PlayerSession.vending_purchase/7`) calls this on the seller
  # session, which runs the whole atomic transaction and replies with the
  # buyer's delta. Kept as its own domain despite being a single message: it is
  # the entire cross-session `VendingHandler` seam, not a session-local tag.
  @impl true
  def handle_call(
        {:vending,
         {:vending_purchase, buyer_char_id, buyer_inventory, buyer_zeny, buyer_stats, buyer_name,
          buy_lines}},
        _from,
        seller_state
      ) do
    VendingHandler.handle_purchase(
      seller_state,
      buyer_char_id,
      buyer_inventory,
      buyer_zeny,
      buyer_stats,
      buyer_name,
      buy_lines
    )
  end

  # Social: pending party/guild invite delivery.
  @impl true
  def handle_call({:social, {:deliver_party_invite, invite}}, _from, state) do
    PartyHandler.handle_invite_delivery(invite, state)
  end

  @impl true
  def handle_call({:social, {:deliver_guild_invite, invite}}, _from, state) do
    GuildHandler.handle_invite_delivery(invite, state)
  end

  # NPC: the single-writer script-effect seam. An NPC interaction process (or
  # MvpReward) applies a state mutation (pay_zeny / give_item / delitem /
  # set_char_var / ...) against this authoritative session. Replies with the
  # fresh game_state or an error; on success the new game_state is also
  # published to the unit registry. The other `:npc` message,
  # `{:run_attached_event, ...}`, is a cast - see the handle_cast clauses.
  @impl true
  def handle_call({:npc, {:script_apply, op}}, _from, state) do
    ScriptEffectHandler.handle_script_apply(op, state)
  end

  @impl true
  def terminate(
        reason,
        %{game_state: _game_state, connection_monitor_ref: connection_monitor_ref} = state
      ) do
    state = SkillTextInputHandler.clear(state)
    state = SkillHandler.cancel_deferred(state)
    state = SpiritSphereHandler.discard(state)
    game_state = PlayerState.clear_pending_forced_movement(state.game_state)
    state = %{state | game_state: game_state}
    Process.demonitor(connection_monitor_ref, [:flush])
    state = HomunculusCommandHandler.terminate(state)
    game_state = state.game_state

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
