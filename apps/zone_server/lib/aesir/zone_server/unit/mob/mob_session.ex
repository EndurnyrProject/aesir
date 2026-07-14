defmodule Aesir.ZoneServer.Unit.Mob.MobSession do
  @moduledoc """
  GenServer managing a single mob's session and state.

  Similar to PlayerSession but for mobs with AI behavior, movement, and combat.
  Each mob instance runs as its own process with independent AI logic.
  """

  use GenServer

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitHp
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor, as: MobSkillExecutor
  alias Aesir.ZoneServer.Mmo.MobSkill.Selector, as: MobSkillSelector
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.QuestHuntCredit
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Phoenix.PubSub

  # AI tick interval in milliseconds
  @ai_tick_interval 1000

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
    GenServer.cast(pid, {:apply_damage, damage, attacker_id})
  end

  @doc """
  Heals the mob.
  """
  @spec heal(pid(), integer()) :: :ok
  def heal(pid, amount) do
    GenServer.cast(pid, {:heal, amount})
  end

  @doc """
  Gets the current mob state.
  """
  @spec get_state(pid()) :: MobState.t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Forces the mob to move to a target position.
  """
  @spec move_to(pid(), integer(), integer()) :: :ok
  def move_to(pid, x, y) do
    GenServer.cast(pid, {:move_to, x, y})
  end

  @doc """
  Sets the mob's AI target.
  """
  @spec set_target(pid(), integer() | nil) :: :ok
  def set_target(pid, target_id) do
    GenServer.cast(pid, {:set_target, target_id})
  end

  @doc """
  Marks the mob as having been stolen from.
  """
  @spec mark_stolen(pid()) :: :ok
  def mark_stolen(pid) do
    GenServer.cast(pid, {:mark_stolen})
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
    GenServer.call(pid, {:attempt_steal, caster_dex, skill_level})
  end

  @doc """
  Suspends the mob's AI loop while its map has no players.

  The mob keeps its full state (HP, aggro history, position) but stops ticking,
  so dormant maps cost no CPU. `wake/1` resumes the loop.
  """
  @spec sleep(pid()) :: :ok
  def sleep(pid) do
    GenServer.cast(pid, :sleep)
  end

  @doc """
  Resumes the AI loop of a mob previously put to sleep with `sleep/1`.
  """
  @spec wake(pid()) :: :ok
  def wake(pid) do
    GenServer.cast(pid, :wake)
  end

  @doc """
  Instantly relocates the mob to a random walkable cell on its map and drops
  its current target (`AL_TELEPORT` flee). Reuses the `:knocked_back` instant
  position-set path; a no-op if no walkable cell is found.
  """
  @spec teleport(pid()) :: :ok
  def teleport(pid) do
    GenServer.cast(pid, {:mob_teleport})
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
    notify_spawn(updated_state)

    # Schedule the first AI tick, or start dormant (and heap-compacted) when the
    # map has no players.
    if awake do
      {:ok, schedule_jittered_ai_tick(updated_state)}
    else
      {:ok, updated_state, :hibernate}
    end
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call({:attempt_steal, caster_dex, skill_level}, _from, %{mob_data: mob_data} = state) do
    cond do
      :boss in (mob_data.modes || []) ->
        {:reply, {:error, :boss}, state}

      state.stolen_from ->
        {:reply, {:error, :already_stolen}, state}

      :rand.uniform(100) > steal_rate(caster_dex, mob_data.stats.dex, skill_level) ->
        {:reply, {:error, :miss}, state}

      true ->
        case steal_drop(mob_data.drops) do
          {:ok, item_id} -> {:reply, {:ok, item_id}, MobState.mark_stolen(state)}
          :error -> {:reply, {:error, :no_drop}, state}
        end
    end
  end

  @impl GenServer
  def handle_cast({:apply_damage, _damage, _attacker_id}, %{is_dead: true} = state) do
    # A dead mob is no longer a valid target. Dropping the hit prevents re-running
    # the death path (and re-awarding experience) during the ~1s window between
    # death and process termination, while it is still in the registry/index.
    {:noreply, state}
  end

  def handle_cast({:apply_damage, damage, attacker_id}, state) do
    {updated_mob, status} = MobState.apply_damage(state, damage)
    current_time = System.system_time(:second)

    # Update last damage time and add aggro if attacker provided
    updated_mob =
      updated_mob
      |> Map.put(:last_damage_time, current_time)
      |> maybe_add_aggro(attacker_id, damage)
      |> AIStateMachine.handle_damage_reaction(attacker_id)
      |> maybe_note_rude_attack(attacker_id)

    # Send HP update packet to nearby players
    notify_hp_update(updated_mob)

    case status do
      :alive ->
        {:noreply, updated_mob}

      :dead ->
        handle_death(updated_mob, attacker_id)
    end
  end

  @impl GenServer
  def handle_cast({:heal, amount}, state) do
    updated_state = MobState.heal(state, amount)

    # Send HP update packet to nearby players
    notify_hp_update(updated_state)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:move_to, x, y}, state) do
    if state.movement_state == :moving do
      {:noreply, state}
    else
      with {:ok, map_data} <- MapCache.get(state.map_name),
           {:ok, [_ | _] = path} <-
             Pathfinding.find_path(
               map_data,
               {state.x, state.y},
               {x, y}
             ) do
        updated_state = MobState.set_path(state, path)

        # Schedule first movement tick immediately to start movement
        Process.send_after(self(), :movement_tick, 0)

        {:noreply, updated_state}
      else
        {:ok, []} ->
          # Already at destination
          {:noreply, state}

        {:error, _reason} ->
          # No path found or map not loaded
          {:noreply, state}
      end
    end
  end

  @impl GenServer
  def handle_cast({:set_target, target_id}, state) do
    updated_state =
      state
      |> MobState.set_target(target_id)
      |> MobState.set_ai_state(if target_id, do: :combat, else: :idle)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:mark_stolen}, state) do
    updated_state = MobState.mark_stolen(state)
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:status_changed, status_id, _event}, %{casting: casting} = state)
      when status_id in [:sc_silence, :sc_stun] and casting != nil do
    # A silence/stun tick landing mid-cast aborts it promptly. The live
    # :cast_complete poll is the authoritative guarantee (a status can be applied
    # without ever emitting this hook); this only shortens the interruption
    # latency when the hook does fire. A live :ai_tick timer keeps AI going.
    {:noreply, abort_cast(state)}
  end

  def handle_cast({:status_changed, _status_id, _event}, state) do
    # Fired by StatusTickManager when one of this mob's statuses ticks or expires.
    # Combat stats are folded live on read (MobState.to_combatant/1) and the
    # icon/opt display delta is already broadcast by the StatusEffect.Interpreter,
    # so there is nothing to recompute here.
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:sleep, %{ai_awake: false} = state), do: {:noreply, state}

  def handle_cast(:sleep, state) do
    if state.ai_timer_ref, do: Process.cancel_timer(state.ai_timer_ref)

    # Shed any in-flight movement and combat intent so the mob is inert while
    # dormant; aggro toward players who left the map must not survive the nap.
    # Hibernating compacts the heap, so a dormant map costs no CPU and little
    # memory until a player shows up again.
    # ponytail: a cast in flight is not cancelled here; its :cast_complete
    # self-heals via the target-invalidation abort. Proper cast interruption
    # lands with Phase 2b (mob-side statuses).
    updated_state =
      state
      |> MobState.stop_movement()
      |> MobState.set_target(nil)
      |> MobState.set_ai_state(:idle)
      |> Map.merge(%{ai_awake: false, ai_timer_ref: nil})

    {:noreply, updated_state, :hibernate}
  end

  @impl GenServer
  def handle_cast(:wake, %{ai_awake: true} = state), do: {:noreply, state}

  def handle_cast(:wake, state) do
    {:noreply, schedule_jittered_ai_tick(%{state | ai_awake: true})}
  end

  @impl GenServer
  def handle_cast({:knocked_back, x, y}, state) do
    updated_state =
      state
      |> MobState.update_position(x, y)
      |> MobState.stop_movement()

    Movement.set_position(:mob, updated_state.instance_id, updated_state, updated_state.map_name)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:mob_teleport}, state) do
    # Instant flee reposition (AL_TELEPORT): reuse the :knocked_back position-set
    # path (spatial-index update + delta-snapshot broadcast), not the walking
    # move_to. A missing cache entry or a fully-blocked map is a benign no-op.
    with {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, {x, y}} <- MapData.random_walkable_cell(map_data) do
      updated_state =
        state
        |> MobState.update_position(x, y)
        |> MobState.stop_movement()
        |> MobState.set_target(nil)
        |> MobState.set_ai_state(:idle)

      Movement.set_position(
        :mob,
        updated_state.instance_id,
        updated_state,
        updated_state.map_name
      )

      {:noreply, updated_state}
    else
      _ -> {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:ai_tick, state) do
    cond do
      state.is_dead ->
        # Dead mobs don't process AI
        {:noreply, state}

      not state.ai_awake ->
        # A tick that raced a :sleep; drop it without rescheduling
        {:noreply, state}

      state.casting != nil ->
        # A casting mob is locked: no movement, no melee, no re-selection.
        # Completion is driven by the separate :cast_complete timer, unless a
        # silence/stun landed mid-cast, in which case the cast is aborted here.
        if cast_interrupted?(state) do
          {:noreply, schedule_ai_tick(abort_cast(state))}
        else
          {:noreply, schedule_ai_tick(state)}
        end

      true ->
        updated_state = state |> run_skill_or_ai() |> schedule_ai_tick()
        {:noreply, updated_state}
    end
  end

  @impl GenServer
  def handle_info(:cast_complete, %{is_dead: true} = state), do: {:noreply, state}

  def handle_info(:cast_complete, %{casting: nil} = state), do: {:noreply, state}

  def handle_info(:cast_complete, %{casting: %{row: row}} = state) do
    # Authoritative silence/stun poll: a status may have landed via a plain apply
    # (no :status_changed hook), so this is the one place that guarantees a
    # silenced cast never fires. Target invalidation surfaces as {:error, _} from
    # the Executor - also a clean abort with no packet. The cooldown is written
    # in every case so an aborted cast cannot be instantly re-rolled every tick.
    updated_state =
      if cast_interrupted?(state) do
        abort_cast(state)
      else
        MobSkillExecutor.execute(state, row)
        now = System.system_time(:millisecond)

        state
        |> MobState.put_skill_cooldown(row.skill, now + row.delay)
        |> MobState.clear_casting()
      end

    if updated_state.ai_timer_ref, do: Process.cancel_timer(updated_state.ai_timer_ref)

    {:noreply, schedule_ai_tick(updated_state)}
  end

  @impl GenServer
  def handle_info(:movement_tick, state) do
    if state.is_dead do
      # Dead mobs don't move
      {:noreply, state}
    else
      # Process movement if mob is moving
      updated_state = process_movement_tick(state)
      {:noreply, updated_state}
    end
  end

  @impl GenServer
  def handle_info(:terminate, state) do
    {:stop, :normal, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    unless state.is_dead do
      Lifecycle.publish_departure(:mob, state.instance_id, state.map_name, :termination)
    end

    SpatialIndex.remove_unit(:mob, state.instance_id)
    Broadcast.publish_mob_despawn(state.map_name, state.instance_id)
    :ok
  end

  # Private Functions

  # rAthena pc_steal_item renewal rate formula, expressed as a percent out of 100.
  @spec steal_rate(non_neg_integer(), non_neg_integer(), pos_integer()) :: integer()
  defp steal_rate(caster_dex, mob_dex, skill_level) do
    div(caster_dex - mob_dex, 2) + 6 * skill_level + 4
  end

  # Walks the drop table in order, skipping steal-protected entries, and rolls
  # each remaining drop's own `rnd(10000) <= rate`. The first roll to succeed
  # wins; an unresolvable item name is treated as a miss on that drop rather
  # than aborting the whole steal.
  @spec steal_drop([MobDrop.t()]) :: {:ok, non_neg_integer()} | :error
  defp steal_drop([]), do: :error

  defp steal_drop([%MobDrop{steal_protected: true} | rest]), do: steal_drop(rest)

  defp steal_drop([%MobDrop{item: item, rate: rate} | rest]) do
    if :rand.uniform(10_000) <= rate do
      case ItemManagement.get_item_by_aegis(item) do
        {:ok, %{id: item_id}} -> {:ok, item_id}
        {:error, _reason} -> steal_drop(rest)
      end
    else
      steal_drop(rest)
    end
  end

  defp maybe_add_aggro(state, nil, _damage), do: state

  defp maybe_add_aggro(state, attacker_id, damage) do
    MobState.add_aggro(state, attacker_id, damage)
  end

  # Records a rude attack when the hit came from beyond the mob's chase range
  # (an attacker it cannot path to). Phase 1 only counts the signal; Phase 2's
  # `rudeattacked` condition consumes it. An attacker whose position can't be
  # resolved is skipped silently.
  defp maybe_note_rude_attack(state, attacker_id) when is_integer(attacker_id) do
    case resolve_attacker_position(attacker_id) do
      {:ok, {x, y}} ->
        if Geometry.chebyshev_distance(x, y, state.x, state.y) >
             MobState.get_chase_range(state) do
          MobState.note_rude_attack(state)
        else
          state
        end

      :error ->
        state
    end
  end

  defp maybe_note_rude_attack(state, _attacker_id), do: state

  # The attacker type isn't known here, so try :player then :mob (mirrors the
  # combat action handler's target resolution).
  defp resolve_attacker_position(attacker_id) do
    case SpatialIndex.get_unit_position(:player, attacker_id) do
      {:ok, {x, y, _map}} ->
        {:ok, {x, y}}

      {:error, :not_found} ->
        case SpatialIndex.get_unit_position(:mob, attacker_id) do
          {:ok, {x, y, _map}} -> {:ok, {x, y}}
          {:error, :not_found} -> :error
        end
    end
  end

  defp handle_death(state, attacker_id) do
    # Mark as dead
    updated_state = MobState.set_dead(state)

    # Notify nearby players of mob death
    notify_despawn(updated_state)
    Lifecycle.publish_death(:mob, state.instance_id, state.map_name)

    announce_kill(state, attacker_id)

    # Notify coordinator of death for respawn scheduling and OnMyMobDead dispatch
    Coordinator.mob_died(state.map_name, state.instance_id, attacker_id)

    # Schedule process termination after a brief delay to handle cleanup
    Process.send_after(self(), :terminate, 1000)

    {:noreply, updated_state}
  end

  # Distributes EXP to every attacker who damaged the mob, proportional to
  # damage dealt (`KillExp.distribute/5`, design "Damage-based EXP share"),
  # then publishes the drop-rolling payload to the killing blow's own session
  # (the only place holding both the drop table and the killer's stats). The
  # mob stays ignorant of who listens; an absent killer simply has no
  # subscriber.
  defp announce_kill(_state, nil), do: :ok

  defp announce_kill(%MobState{mob_data: mob_data, aggro_list: aggro_list} = state, attacker_id) do
    KillExp.distribute(
      aggro_list,
      mob_data.base_exp,
      mob_data.job_exp,
      mob_data.level,
      state.map_name
    )

    QuestHuntCredit.credit(attacker_id, mob_data.id, state.map_name, {state.x, state.y})

    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{attacker_id}",
      {:mob_killed,
       %{
         mob_id: mob_data.id,
         drops: mob_data.drops,
         mob_level: mob_data.level,
         map: state.map_name,
         x: state.x,
         y: state.y
       }}
    )
  end

  defp process_ai(state) do
    AIStateMachine.process_ai(state)
  end

  # Skill selection runs before the melee/movement state machine: a tick that
  # picks a row either starts a cast (locking the mob until :cast_complete) or
  # fires it instantly; only a nil selection falls through to the normal AI.
  # The very first tick after spawn selects with the :spawn event so `onspawn`
  # rows can fire. `now` is System.system_time(:millisecond), the same clock
  # the melee path uses for last_attack_time, so cooldown expiry lines up.
  defp run_skill_or_ai(state) do
    if cast_interrupted?(state) do
      # Silenced/stunned: skip skill selection entirely so no new cast begins.
      # Melee/movement still runs through its own can_attack?/can_move? gates.
      process_ai(%{state | spawn_tick_pending?: false})
    else
      now = System.system_time(:millisecond)
      event = if state.spawn_tick_pending?, do: :spawn, else: :tick
      state = %{state | spawn_tick_pending?: false}

      case MobSkillSelector.select(state, MobSkillDb.rows_for(state.mob_id),
             now: now,
             event: event
           ) do
        {:cast, row} -> begin_cast(state, row, now)
        nil -> process_ai(state)
      end
    end
  end

  defp begin_cast(state, %{cast_time: 0} = row, now) do
    MobSkillExecutor.broadcast_casting(state, row)
    MobSkillExecutor.execute(state, row)
    MobState.put_skill_cooldown(state, row.skill, now + row.delay)
  end

  defp begin_cast(state, row, now) do
    MobSkillExecutor.broadcast_casting(state, row)
    timer_ref = Process.send_after(self(), :cast_complete, row.cast_time)

    MobState.set_casting(state, %{
      row: row,
      complete_at: now + row.cast_time,
      timer_ref: timer_ref
    })
  end

  # A silence or stun on this mob interrupts skill casting (melee/movement are
  # gated separately by the status interpreter).
  defp cast_interrupted?(state) do
    StatusStorage.has_status?(:mob, state.instance_id, :sc_silence) or
      StatusStorage.has_status?(:mob, state.instance_id, :sc_stun)
  end

  # Aborts an in-flight cast cleanly: cancels the pending :cast_complete timer so
  # a stale one cannot fire against a later cast, writes the skill's delay
  # cooldown (mirroring the target-invalidation abort so there is no instant
  # re-roll), and clears the cast descriptor. No damage/effect/packet fires.
  defp abort_cast(%{casting: %{row: row} = casting} = state) do
    case Map.get(casting, :timer_ref) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    now = System.system_time(:millisecond)

    state
    |> MobState.put_skill_cooldown(row.skill, now + row.delay)
    |> MobState.clear_casting()
  end

  defp process_movement_tick(%{movement_state: :standing} = state) do
    state
  end

  defp process_movement_tick(%{movement_state: :moving, walk_path: []} = state) do
    MobState.stop_movement(state)
  end

  defp process_movement_tick(%{movement_state: :moving} = state) do
    case state.walk_path do
      [{next_x, next_y} | _] = walk_path ->
        if next_cell_walkable?(state.map_name, next_x, next_y) do
          step_mob(state, {next_x, next_y}, tl(walk_path))
        else
          handle_blocked_mob(state, List.last(walk_path))
        end
    end
  end

  defp step_mob(state, {next_x, next_y}, remaining_path) do
    # Timer interval from the live walk_speed and the per-cell movement cost.
    interval =
      MovementEngine.step_delay(state.walk_speed, {state.x, state.y}, {next_x, next_y})

    # Facing toward the cell we are stepping into.
    dir = Geometry.calculate_direction(state.x, state.y, next_x, next_y)

    # Update mob state FIRST to maintain consistency
    updated_state =
      state
      |> MobState.update_position(next_x, next_y)
      |> MobState.update_direction(dir)
      |> Map.put(:walk_path, remaining_path)

    # Route through the single choke point so the spatial index + registry
    # are synced and the unit is marked dirty for the per-map broadcaster.
    Movement.set_position(
      :mob,
      updated_state.instance_id,
      updated_state,
      updated_state.map_name
    )

    # Schedule next movement tick with appropriate interval
    if remaining_path != [] do
      Process.send_after(self(), :movement_tick, interval)
      updated_state
    else
      # Path completed: stop and broadcast the standing transition so the
      # client's last snapshot sample flips move_state back to idle.
      stopped_state = MobState.stop_movement(updated_state)

      Movement.set_position(
        :mob,
        stopped_state.instance_id,
        stopped_state,
        stopped_state.map_name
      )

      stopped_state
    end
  end

  defp handle_blocked_mob(state, destination) do
    with {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, [_ | _] = path} <-
           Pathfinding.find_path(map_data, {state.x, state.y}, destination) do
      updated_state = MobState.set_path(state, path)
      Process.send_after(self(), :movement_tick, 0)
      updated_state
    else
      _ ->
        stopped_state = MobState.stop_movement(state)

        Movement.set_position(
          :mob,
          stopped_state.instance_id,
          stopped_state,
          stopped_state.map_name
        )

        stopped_state
    end
  end

  defp next_cell_walkable?(map_name, x, y) do
    case MapCache.get(map_name) do
      {:ok, map_data} -> MapData.walkable?(map_data, x, y)
      {:error, _} -> false
    end
  end

  # AI logic is now handled by AIStateMachine module

  defp schedule_ai_tick(state, interval \\ @ai_tick_interval) do
    %{state | ai_timer_ref: Process.send_after(self(), :ai_tick, interval)}
  end

  # First tick after spawn/wake lands at a random offset so a whole map waking
  # at once doesn't tick every mob in the same millisecond thereafter.
  defp schedule_jittered_ai_tick(state) do
    schedule_ai_tick(state, :rand.uniform(@ai_tick_interval))
  end

  # Mob Visibility Helper Functions

  defp notify_hp_update(%MobState{} = mob_state) do
    packet = %UnitHp{
      id: mob_state.instance_id,
      hp: max(0, mob_state.hp),
      max_hp: max(1, mob_state.max_hp)
    }

    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp notify_spawn(%MobState{} = mob_state) do
    packet = create_spawn_packet(mob_state)
    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp notify_despawn(%MobState{} = mob_state) do
    packet = %UnitDespawn{
      gid: mob_state.instance_id,
      reason: DespawnReason.died()
    }

    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp create_spawn_packet(%MobState{} = mob_state) do
    %{
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue
    } =
      StatusDisplay.spawn_state(:mob, mob_state.instance_id)

    %UnitSpawn{
      object_type: ObjectType.mob(),
      aid: mob_state.instance_id,
      gid: mob_state.instance_id,
      speed: mob_state.walk_speed,
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue,
      job: mob_state.mob_id,
      sex: 0,
      x: mob_state.x,
      y: mob_state.y,
      dir: mob_state.dir,
      clevel: mob_state.mob_data.level,
      max_hp: mob_state.max_hp,
      hp: mob_state.hp,
      is_boss: MobState.is_boss?(mob_state),
      name: mob_state.mob_data.name,
      moving: false
    }
  end

  # Broadcasting Helper Functions

  defp broadcast_to_nearby_players(%MobState{} = mob_state, packet) do
    Broadcast.to_in_range(
      mob_state.map_name,
      mob_state.x,
      mob_state.y,
      mob_state.view_range,
      packet
    )
  end
end
