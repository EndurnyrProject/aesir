defmodule Aesir.ZoneServer.Unit.Mob.MobSession do
  @moduledoc """
  GenServer managing a single mob's session and state.

  Similar to PlayerSession but for mobs with AI behavior, movement, and combat.
  Each mob instance runs as its own process with independent AI logic.
  """

  use GenServer

  require Logger

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.PendingWeaponHit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.Mob.StealOps
  alias Aesir.ZoneServer.Unit.SpatialIndex

  # Public API

  @doc """
  Starts a mob session.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{state: _mob_state} = args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Applies damage to the mob.
  """
  @spec apply_damage(pid(), integer(), integer() | nil) :: :ok
  def apply_damage(pid, damage, attacker_id \\ nil) do
    GenServer.cast(pid, {:combat, {:apply_damage, damage, attacker_id}})
  end

  @spec apply_walk_delay(pid(), non_neg_integer()) :: :ok
  def apply_walk_delay(pid, duration),
    do: GenServer.cast(pid, {:movement, {:apply_walk_delay, duration}})

  @doc """
  Heals the mob.
  """
  @spec heal(pid(), integer()) :: :ok
  def heal(pid, amount) do
    GenServer.cast(pid, {:unit, {:heal, amount}})
  end

  @doc """
  Drains `amount` SP from the mob, clamped at 0.

  Mobs spend no SP to cast; their SP pool exists only so drains
  (`SA_SPELLBREAKER`) have something real to take. A dead mob is skipped, like
  `apply_damage/3`. Shares the converged `{:unit, {:drain_sp, _}}` tag with
  `PlayerSession.consume_sp/2`.
  """
  @spec zap_sp(pid(), non_neg_integer()) :: :ok
  def zap_sp(pid, amount) do
    GenServer.cast(pid, {:unit, {:drain_sp, amount}})
  end

  @doc """
  Notifies the mob that one of its statuses ticked or expired.

  Fired by `StatusTickManager` when a status hits its tick interval or
  expiration; may abort an in-flight cast if the status is a silence or stun.
  """
  @spec notify_status_changed(pid(), atom(), atom()) :: :ok
  def notify_status_changed(pid, status_id, event) do
    GenServer.cast(pid, {:casting, {:status_changed, status_id, event}})
  end

  @doc """
  Gets the current mob state.
  """
  @spec get_state(pid()) :: MobState.t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc "Delivers an asynchronous resolution for this mob's pending weapon hit."
  @spec resolve_pending_weapon_hit(pid(), reference(), :resume | {:suppress, reference()}) :: :ok
  def resolve_pending_weapon_hit(pid, id, resolution) do
    send(pid, {:pending_weapon_hit_result, id, resolution})
    :ok
  end

  @doc "Attaches the Root-owned link to this mob's pending weapon hit."
  @spec claim_pending_weapon_hit(pid(), reference(), term(), term()) ::
          :ok | {:error, :invalid_claim}
  def claim_pending_weapon_hit(pid, id, link_id, coordinator_pid)
      when is_reference(link_id) and is_pid(coordinator_pid) do
    send(pid, {:pending_weapon_hit_claimed, id, link_id, coordinator_pid})
    :ok
  end

  def claim_pending_weapon_hit(_pid, _id, _link_id, _coordinator_pid),
    do: {:error, :invalid_claim}

  @doc """
  Forces the mob to move to a target position.
  """
  @spec move_to(pid(), integer(), integer()) :: :ok
  def move_to(pid, x, y) do
    GenServer.cast(pid, {:movement, {:move_to, x, y}})
  end

  @doc """
  Sets the mob's AI target.
  """
  @spec set_target(pid(), integer() | nil) :: :ok
  def set_target(pid, target_id) do
    GenServer.cast(pid, {:ai, {:set_target, target_id}})
  end

  @doc """
  Marks the mob as having been stolen from.
  """
  @spec mark_stolen(pid()) :: :ok
  def mark_stolen(pid) do
    GenServer.cast(pid, {:steal, :mark})
  end

  @doc """
  Attempts to steal one item from this mob (TF_STEAL).

  Runs the full rate roll, per-drop roll and `stolen_from` flip inside the
  mob's own process so concurrent attempts can't both succeed. Rejects bosses
  and mobs already stolen from without consuming a roll. Returns `{:ok,
  item_id}` on a successful steal, or `{:error, reason}` (`:boss`,
  `:already_stolen`, `:miss`, `:no_drop`) — all but `:boss`/`:already_stolen`
  leave `stolen_from` untouched, so the caller may retry.
  """
  @spec attempt_steal(pid(), non_neg_integer(), pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def attempt_steal(pid, caster_dex, skill_level) do
    GenServer.call(pid, {:steal, {:attempt, caster_dex, skill_level}})
  end

  @doc """
  Force-cancels this mob's in-flight cast and reports what was cancelled.

  Unconditional: it ignores the row's `cancelable` flag, mirroring rAthena's
  forced `unit_skillcastcancel(target, 0)` (`spellbreaker.cpp:47`), so no
  interruptibility model is needed. Returns the interrupted skill's identity so
  the caller can bill the cast synchronously (SA_SPELLBREAKER's SP math).

  Running in the mob's own process serializes it against that mob's pending
  `{:casting, :complete}`: a cast that completed first has already cleared
  `casting`, so this reports `{:error, :not_casting}` rather than billing a
  cast that already fired. A dead mob is likewise never casting as far as
  callers are concerned (its process outlives death briefly, and
  `handle_death/2` leaves the descriptor intact).
  """
  @spec interrupt_cast(pid()) ::
          {:ok, %{skill: String.t(), skill_id: integer(), level: pos_integer()}}
          | {:error, :not_casting}
  def interrupt_cast(pid) do
    GenServer.call(pid, {:casting, :interrupt})
  end

  @doc """
  Suspends the mob's AI loop while its map has no players.

  The mob keeps its full state (HP, aggro history, position) but stops ticking,
  so dormant maps cost no CPU. `wake/1` resumes the loop.
  """
  @spec sleep(pid()) :: :ok
  def sleep(pid) do
    GenServer.cast(pid, {:ai, :sleep})
  end

  @doc """
  Resumes the AI loop of a mob previously put to sleep with `sleep/1`.
  """
  @spec wake(pid()) :: :ok
  def wake(pid) do
    GenServer.cast(pid, {:ai, :wake})
  end

  @doc """
  Instantly relocates the mob to a random walkable cell on its map and drops
  its current target (`AL_TELEPORT` flee). Reuses the `{:movement,
  {:knocked_back, x, y}}` instant position-set path; a no-op if no walkable
  cell is found.
  """
  @spec teleport(pid()) :: :ok
  def teleport(pid) do
    GenServer.cast(pid, {:movement, :teleport})
  end

  @doc """
  Stops the mob session.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # GenServer Callbacks

  @impl GenServer
  def init(%{state: mob_state} = args) do
    awake = Map.get(args, :awake, true)

    # Set this process as the mob's process
    updated_state =
      mob_state
      |> MobState.set_process_pid(self())
      |> Map.put(:ai_awake, awake)

    # Register in spatial index
    :ok =
      SpatialIndex.add_unit(
        :mob,
        updated_state.instance_id,
        updated_state.x,
        updated_state.y,
        updated_state.map_name
      )

    # Notify nearby players of mob spawn
    SpawnView.notify_spawn(updated_state)

    # Schedule the first AI tick, or start dormant (and heap-compacted) when the
    # map has no players.
    if awake do
      {:ok, AiHandler.schedule_jittered_ai_tick(updated_state)}
    else
      {:ok, updated_state, :hibernate}
    end
  end

  # get_state stays bare: a ubiquitous utility call, not a domain message.
  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Casting: the forced-interrupt call (SA_SPELLBREAKER).
  @impl GenServer
  def handle_call({:casting, :interrupt}, _from, state) do
    CastingHandler.handle_interrupt_cast(state)
  end

  # Steal: the TF_STEAL roll, serialized inside this mob's own process.
  @impl GenServer
  def handle_call({:steal, {:attempt, caster_dex, skill_level}}, _from, state) do
    case StealOps.attempt_steal(state, caster_dex, skill_level) do
      {:ok, item_id, new_state} -> {:reply, {:ok, item_id}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # AI: sleep/wake suspension of the AI loop and target (re)assignment.
  @impl GenServer
  def handle_cast({:ai, :sleep}, state) do
    AiHandler.handle_sleep(state)
  end

  def handle_cast({:ai, :wake}, state) do
    AiHandler.handle_wake(state)
  end

  def handle_cast({:ai, {:set_target, target_id}}, state) do
    AiHandler.handle_set_target(state, target_id)
  end

  # Casting: a status tick/expiry that may interrupt an in-flight cast.
  @impl GenServer
  def handle_cast({:casting, {:status_changed, status_id, event}}, state) do
    CastingHandler.handle_status_changed(status_id, event, state)
  end

  # Movement: pathing kickoff, the instant teleport reposition, and the
  # knockback landing (stop + position-set, same shape as the player path) all
  # delegate to MovementHandler. The walk-delay slow stays inline: it is not
  # the same operation as knockback - a mob unconditionally resets its movement
  # state with no publish, while knockback publishes the landing cell.
  @impl GenServer
  def handle_cast({:movement, {:move_to, x, y}}, state) do
    MovementHandler.handle_move_to(state, x, y)
  end

  def handle_cast({:movement, :teleport}, state) do
    MovementHandler.handle_teleport(state)
  end

  def handle_cast({:movement, {:apply_walk_delay, duration}}, state) do
    now = System.monotonic_time(:millisecond)
    {:noreply, state |> MobState.apply_walk_delay(duration, now) |> MobState.stop_movement()}
  end

  def handle_cast({:movement, {:knocked_back, x, y}}, state) do
    MovementHandler.handle_knocked_back(state, x, y)
  end

  # Combat: damage application (death handling lives in CombatHandler).
  @impl GenServer
  def handle_cast({:combat, {:apply_damage, damage, attacker_id}}, state) do
    CombatHandler.handle_apply_damage(damage, attacker_id, state)
  end

  # Unit: heal and SP drain. Heal broadcasts the new HP and is ungated (a
  # corpse still heals, as before); SP drain publishes nothing (mobs have no
  # client-visible SP) and no-ops on a dead mob. Neither touches the unit
  # registry. Non-positive amounts are silent no-ops.
  @impl GenServer
  def handle_cast({:unit, {:heal, amount}}, state)
      when is_integer(amount) and amount > 0 do
    state = %{state | hp: min(state.hp + amount, state.max_hp)}
    SpawnView.notify_hp_update(state)
    {:noreply, state}
  end

  def handle_cast({:unit, {:heal, _amount}}, state), do: {:noreply, state}

  def handle_cast({:unit, {:drain_sp, _amount}}, %{is_dead: true} = state), do: {:noreply, state}

  def handle_cast({:unit, {:drain_sp, amount}}, state)
      when is_integer(amount) and amount > 0 do
    {:noreply, %{state | sp: max(0, state.sp - amount)}}
  end

  def handle_cast({:unit, {:drain_sp, _amount}}, state), do: {:noreply, state}

  # Steal: mark this mob as already stolen from (TF_STEAL success path).
  @impl GenServer
  def handle_cast({:steal, :mark}, state) do
    updated_state = MobState.mark_stolen(state)
    {:noreply, updated_state}
  end

  # Unknown casts must not crash a live mob session.
  def handle_cast(message, state) do
    Logger.error("MobSession #{state.instance_id} received unknown cast: #{inspect(message)}")
    {:noreply, state}
  end

  # AI: the self-armed periodic tick.
  @impl GenServer
  def handle_info({:ai, :tick}, state) do
    AiHandler.handle_ai_tick(state)
  end

  # Casting: the self-armed cast-timer resolution.
  @impl GenServer
  def handle_info({:casting, :complete}, state) do
    CastingHandler.handle_cast_complete(state)
  end

  # Movement: the self-armed per-step walk tick.
  @impl GenServer
  def handle_info({:movement, :tick}, state) do
    MovementHandler.handle_movement_tick(state)
  end

  # Skill: the generic deferred-effect seam (`Skill.defer/3`) that runs
  # `module.deferred/2` on the mob's own state.
  @impl GenServer
  def handle_info({:skill, {:deferred, module, payload}}, state) do
    if function_exported?(module, :deferred, 2) do
      _ = module.deferred(payload, state)
    else
      Logger.error(
        "MobSession dropped deferred skill effect: #{inspect(module)} does not implement deferred/2"
      )
    end

    {:noreply, state}
  end

  # Combat: the Root-owned pending weapon hit - async resolution, the deadline
  # timeout, and the Coordinator claim.
  @impl GenServer
  def handle_info({:pending_weapon_hit_result, id, resolution}, state)
      when resolution == :resume or (is_tuple(resolution) and tuple_size(resolution) == 2) do
    case state.pending_weapon_hit do
      %PendingWeaponHit{id: ^id} = pending ->
        case PendingWeaponHit.resolve(pending, resolution) do
          {:ok, %{phase: :resumed}} -> {:noreply, resume_pending_weapon_hit(state, pending)}
          {:ok, %{phase: :suppressed}} -> {:noreply, clear_pending_weapon_hit(state, pending)}
          :already_resolved -> {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:pending_weapon_hit_claimed, id, link_id, coordinator_pid}, state)
      when is_reference(link_id) and is_pid(coordinator_pid) do
    case state.pending_weapon_hit do
      %PendingWeaponHit{id: ^id} = pending ->
        case PendingWeaponHit.claim(pending, link_id) do
          {:ok, claimed} ->
            send(coordinator_pid, PendingWeaponHit.claim_submission_message(claimed))
            {:noreply, %{state | pending_weapon_hit: claimed}}

          :already_resolved ->
            {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:pending_weapon_hit_timeout, id}, state) do
    case state.pending_weapon_hit do
      %PendingWeaponHit{id: ^id, deadline_at: deadline_at} = pending ->
        if deadline_at <= System.monotonic_time(:millisecond) do
          {:noreply, resume_pending_weapon_hit(state, pending)}
        else
          {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  # :terminate stays bare: a singleton lifecycle atom (post-death cleanup timer).
  @impl GenServer
  def handle_info(:terminate, state) do
    {:stop, :normal, state}
  end

  # Unknown messages must not crash a live mob session.
  def handle_info(message, state) do
    Logger.error("MobSession #{state.instance_id} received unknown info: #{inspect(message)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    state = MobState.cancel_pending_weapon_hit(state)

    unless state.is_dead do
      Lifecycle.publish_departure(:mob, state.instance_id, state.map_name, :termination)
    end

    SpatialIndex.remove_unit(:mob, state.instance_id)
    Broadcast.publish_mob_despawn(state.map_name, state.instance_id)
    :ok
  end

  # Runs the deferred weapon swing once its Root resolution resumes it, then
  # re-arms the ordinary attack cadence. A resumed swing must settle inline and
  # never spawn a fresh pending hit.
  defp resume_pending_weapon_hit(state, pending) do
    state = %{state | pending_weapon_hit: nil}

    case Combat.resume_mob_attack(state, pending) do
      :ok ->
        clear_pending_weapon_hit(state, pending)

      {:pending, _next_pending} ->
        raise "resuming a pending weapon hit must not create another pending hit"

      {:error, _reason} ->
        state
    end
  end

  # Drops the pending hit, restores the melee cadence bookkeeping, and reschedules
  # the AI tick at the swing's own next-attack delay.
  defp clear_pending_weapon_hit(state, pending) do
    if state.ai_timer_ref, do: Process.cancel_timer(state.ai_timer_ref)

    delay = max(pending.next_attack_at - System.monotonic_time(:millisecond), 0)

    %{state | pending_weapon_hit: nil, last_attack_time: pending.swing_at}
    |> AiHandler.schedule_ai_tick(delay)
  end
end
