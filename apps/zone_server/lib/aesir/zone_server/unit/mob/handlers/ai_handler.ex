defmodule Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler do
  @moduledoc """
  Handles a mob's AI loop: the hard think the map sends per nearby player
  (`{:ai, {:hard, player_id}}`), the mob's own 1 s `{:ai, :tick}` (the lazy
  think), the attack timer and chase resume messages the thinks arm, the
  attacked event's think, sleep/wake suspension of the loop while its map has
  no players, and AI target locks.

  Cross-references `Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler` to gate
  and abort a locked AI tick and to start a cast picked by skill selection;
  `CastingHandler` calls back into this module to reschedule the AI tick after
  a cast resolves.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.MobSkill.Selector, as: MobSkillSelector
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Slaves
  alias Aesir.ZoneServer.Unit.Mob.StateCommit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # The lazy AI runs once per second on the mob's own tick; the hard AI is
  # driven per player by the map (`Map.Coordinator`), which sends a hard think
  # to every mob within the visual area plus the active range of each player.
  @ai_tick_interval 1000
  @skill_interval 1000
  @hard_think_guard 200

  @doc """
  Processes the periodic `{:ai, :tick}`: dead and dormant mobs drop it, any
  other mob runs the lazy think (`lazy_think/1`) and reschedules the tick a
  second later.
  """
  @spec handle_ai_tick(MobState.t()) :: {:noreply, MobState.t()}
  def handle_ai_tick(state) do
    cond do
      state.is_dead -> {:noreply, state}
      not state.ai_awake -> {:noreply, state}
      true -> {:noreply, state |> timed(&lazy_think/1) |> schedule_ai_tick()}
    end
  end

  @doc """
  Processes an `{:ai, {:hard, player_id}}` cast from the map's per-player pass:
  the player spots the mob, which runs the hard think (`think/1`); a mob near
  several players thinks once per player. Dead and dormant mobs drop it.
  """
  @spec handle_hard_think(MobState.t(), integer()) :: {:noreply, MobState.t()}
  def handle_hard_think(%MobState{is_dead: true} = state, _player_id), do: {:noreply, state}
  def handle_hard_think(%MobState{ai_awake: false} = state, _player_id), do: {:noreply, state}

  def handle_hard_think(state, player_id),
    do: {:noreply, timed(state, &(&1 |> spot(player_id) |> think()))}

  @doc """
  Processes the `{:ai, {:attack_timer, at}}` message of the attack timer armed
  for `at`; a stale one (the timer was re-armed or dropped since) is ignored.
  The end of the attack timer cancels the attack and unlocks a target that is
  gone or no longer visible; otherwise the whole hard think runs, whether or
  not a player is near.
  """
  @spec handle_attack_timer(MobState.t(), integer()) :: {:noreply, MobState.t()}
  def handle_attack_timer(%MobState{attack_timer_at: at} = state, at) do
    state = %{state | attack_timer_at: nil}

    if AIStateMachine.attack_target_visible?(state),
      do: {:noreply, timed(state, &think/1)},
      else:
        {:noreply,
         state
         |> MobState.stop_attack()
         |> AIStateMachine.unlock_target(now())
         |> StateCommit.commit()}
  end

  def handle_attack_timer(state, _at), do: {:noreply, state}

  @doc """
  Processes the `{:ai, {:chase_resume, at}}` message of a chase walk waiting
  for the walk delay that ends at `at`; a stale one is ignored. The walk starts
  once the delay has passed and the mob may move; a still-running delay books
  the resume again.
  """
  @spec handle_chase_resume(MobState.t(), integer()) :: {:noreply, MobState.t()}
  def handle_chase_resume(%MobState{chase_resume_at: at} = state, at),
    do: {:noreply, timed(state, &AIStateMachine.resume_chase/1)}

  def handle_chase_resume(state, _at), do: {:noreply, state}

  @doc "Runs the walk cell's chase check and arms any attack timer the order creates."
  @spec walk_chase(MobState.t(), boolean(), boolean()) ::
          {:continue | :stop | {:repath, {integer(), integer()}}, MobState.t()}
  def walk_chase(state, progressed?, fullcheck?) do
    {action, updated} = AIStateMachine.walk_chase(state, progressed?, fullcheck?)
    {action, updated |> arm_timers(state) |> StateCommit.commit()}
  end

  # Runs `fun` on the state and arms the attack timer and chase resume
  # messages it booked.
  defp timed(state, fun) do
    state |> fun.() |> arm_timers(state) |> StateCommit.commit()
  end

  defp arm_timers(state, before) do
    state
    |> arm(:attack_timer_at, before, now(), fn at -> {:ai, {:attack_timer, at}} end)
    |> arm(:chase_resume_at, before, System.monotonic_time(:millisecond), fn at ->
      {:ai, {:chase_resume, at}}
    end)
  end

  defp arm(state, key, before, clock_now, message) do
    at = Map.fetch!(state, key)

    if at != nil and at != Map.fetch!(before, key),
      do: Process.send_after(self(), message.(at), max(at - clock_now, 0))

    state
  end

  defp now, do: System.system_time(:millisecond)

  defp spot(state, player_id), do: %{state | spotted_by: MapSet.put(state.spotted_by, player_id)}

  # The lazy think, once per second on the mob's own tick: nothing within
  # 200 ms of a hard think or within the skill interval; a slave does nothing
  # else; otherwise the target is dropped, then a mob a player has spotted
  # takes a due random walk, or checks its skills while standing.
  defp lazy_think(state), do: lazy_attempt(state, now())

  defp lazy_attempt(state, now) do
    state = clean_spotted(state)

    cond do
      now - (state.next_think_at || 0) < @hard_think_guard ->
        state

      state.last_skillcheck != nil and now - state.last_skillcheck < @skill_interval ->
        state

      state.master_id != nil ->
        if MapSet.size(state.spotted_by) > 0,
          do: state |> Slaves.process(now) |> elem(1),
          else: state

      true ->
        lazy_act(AIStateMachine.unlock_target(state, now), now)
    end
  end

  # A spotted mob takes a due random walk, or checks its skills while standing.
  defp lazy_act(state, now) do
    mono = System.monotonic_time(:millisecond)
    spotted? = MapSet.size(state.spotted_by) > 0

    cond do
      state.next_walktime != nil and state.next_walktime < now and
          AIStateMachine.can_move?(state, mono) ->
        if spotted?, do: state |> AIStateMachine.random_walk(now, mono) |> elem(1), else: state

      state.movement_state != :moving and spotted? and state.casting == nil ->
        state |> use_skill(:tick, now) |> elem(1)

      true ->
        state
    end
  end

  # Players who left the world no longer count as having spotted the mob.
  defp clean_spotted(state) do
    spotted =
      state.spotted_by
      |> Enum.filter(&match?({:ok, _unit}, UnitRegistry.get_unit(:player, &1)))
      |> MapSet.new()

    %{state | spotted_by: spotted}
  end

  @doc """
  Processes an `{:ai, {:attacked, attacker_ref, norm?}}` event, the end of a
  landed hit's walk delay: stores the retaliation target (a slave's or a
  player summon's master, else the attacker) as the pending attacked event,
  leaves the aggressive mode, and runs the hard think at once through its own
  gates, without moving the tick schedule. A dormant mob wakes its AI loop, so
  the mob keeps acting after the think. A dead, casting or resting mob keeps
  the event for its next think; an attacker gone from the world delivers
  nothing.
  """
  @spec handle_attacked(MobState.t(), Ref.t(), boolean()) :: {:noreply, MobState.t()}
  def handle_attacked(state, attacker_ref, norm?) do
    case retaliation_target(attacker_ref) do
      nil ->
        {:noreply, state}

      target_ref ->
        state = state |> MobState.set_attacked(target_ref, norm?) |> wake_for_attacked()

        if state.is_dead, do: {:noreply, state}, else: {:noreply, timed(state, &think/1)}
    end
  end

  defp wake_for_attacked(%MobState{ai_awake: false, is_dead: false} = state),
    do: schedule_ai_tick(%{state | ai_awake: true})

  defp wake_for_attacked(state), do: state

  defp retaliation_target({:mob, id} = attacker_ref) do
    case UnitRegistry.get_unit(:mob, id) do
      {:ok, {_module, %MobState{master_id: master_id}, _pid}} when is_integer(master_id) ->
        {:mob, master_id}

      {:ok, {_module, %MobState{owner_player_id: owner_id}, _pid}} when is_integer(owner_id) ->
        {:player, owner_id}

      {:ok, _unit} ->
        attacker_ref

      {:error, :not_found} ->
        nil
    end
  end

  defp retaliation_target({type, id} = attacker_ref) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, _unit} -> attacker_ref
      {:error, :not_found} -> nil
    end
  end

  @doc """
  Suspends the AI loop for an `{:ai, :sleep}` cast: sheds in-flight
  movement/combat intent and hibernates so a dormant map costs no CPU. A
  no-op if already asleep.
  """
  @spec handle_sleep(MobState.t()) ::
          {:noreply, MobState.t()} | {:noreply, MobState.t(), :hibernate}
  def handle_sleep(%{ai_awake: false} = state), do: {:noreply, state}

  def handle_sleep(state) do
    if state.ai_timer_ref, do: Process.cancel_timer(state.ai_timer_ref)

    # Shed any in-flight movement and combat intent so the mob is inert while
    # dormant; aggro toward players who left the map must not survive the nap.
    # Hibernating compacts the heap, so a dormant map costs no CPU and little
    # memory until a player shows up again.
    # ponytail: a cast in flight is not cancelled here; its {:casting, :complete}
    # self-heals via the target-invalidation abort. Proper cast interruption
    # lands with Phase 2b (mob-side statuses).
    updated_state =
      state
      |> MobState.stop_movement()
      |> MobState.stop_attack()
      |> MobState.set_target(nil)
      |> MobState.clear_attacked()
      |> MobState.set_state(:idle)
      |> Map.merge(%{ai_awake: false, ai_timer_ref: nil})

    {:noreply, StateCommit.commit(updated_state), :hibernate}
  end

  @doc """
  Resumes the AI loop for an `{:ai, :wake}` cast. A no-op if already awake.
  """
  @spec handle_wake(MobState.t()) :: {:noreply, MobState.t()}
  def handle_wake(%{ai_awake: true} = state), do: {:noreply, state}

  def handle_wake(state) do
    {:noreply, schedule_jittered_ai_tick(%{state | ai_awake: true})}
  end

  @doc "Redirects only a living mob whose current target still matches."
  @spec handle_redirect_target(MobState.t(), tuple(), tuple()) ::
          {:reply, :ok | {:error, atom()}, MobState.t()}
  def handle_redirect_target(
        %MobState{is_dead: false, target_ref: expected_ref} = state,
        expected_ref,
        new_ref
      ) do
    {:reply, :ok, state |> MobState.set_target(new_ref) |> StateCommit.commit()}
  end

  def handle_redirect_target(%MobState{is_dead: true} = state, _expected_ref, _new_ref),
    do: {:reply, {:error, :dead}, state}

  def handle_redirect_target(%MobState{} = state, _expected_ref, _new_ref),
    do: {:reply, {:error, :target_changed}, state}

  @doc """
  Locks the mob's AI target for an `{:ai, {:set_target, target_ref}}` cast (a
  taunt, `AIStateMachine.lock_target/3`), or drops it when cleared; the next
  think acts on it.
  """
  @spec handle_set_target(MobState.t(), Ref.t() | integer() | nil) :: {:noreply, MobState.t()}
  def handle_set_target(state, nil),
    do:
      {:noreply,
       state
       |> AIStateMachine.unlock_target(System.system_time(:millisecond))
       |> StateCommit.commit()}

  def handle_set_target(state, target_id) when is_integer(target_id),
    do: handle_set_target(state, {:player, target_id})

  def handle_set_target(state, target_ref),
    do: {:noreply, state |> AIStateMachine.lock_target(target_ref, false) |> StateCommit.commit()}

  @doc """
  Locks the mob's AI target onto its provoker for an `{:ai, {:provoke,
  target_ref}}` cast (`AIStateMachine.lock_target/3` with the provoke flag).
  """
  @spec handle_provoke(MobState.t(), Ref.t()) :: {:noreply, MobState.t()}
  def handle_provoke(state, target_ref),
    do: {:noreply, state |> AIStateMachine.lock_target(target_ref, true) |> StateCommit.commit()}

  @doc """
  Attacks `target_ref` once for an `{:attack_intent, ref}` nudge (Poison
  React's counter) without changing the mob's target; dead mobs ignore it.
  """
  @spec handle_attack_intent(MobState.t(), tuple()) :: {:noreply, MobState.t()}
  def handle_attack_intent(%MobState{is_dead: true} = state, _target_ref), do: {:noreply, state}

  def handle_attack_intent(%MobState{} = state, target_ref),
    do: {:noreply, state |> AIStateMachine.attack_once(target_ref) |> StateCommit.commit()}

  @doc """
  Schedules the next `{:ai, :tick}` after `interval` milliseconds (defaults to
  the lazy tick interval), stamping the new timer ref on the state.
  """
  @spec schedule_ai_tick(MobState.t(), non_neg_integer()) :: MobState.t()
  def schedule_ai_tick(state, interval \\ @ai_tick_interval) do
    %{state | ai_timer_ref: Process.send_after(self(), {:ai, :tick}, interval)}
  end

  @doc """
  Schedules the first tick after spawn/wake at a random offset so a whole map
  waking at once doesn't tick every mob in the same millisecond thereafter.
  """
  @spec schedule_jittered_ai_tick(MobState.t()) :: MobState.t()
  def schedule_jittered_ai_tick(state) do
    schedule_ai_tick(state, :rand.uniform(@ai_tick_interval))
  end

  # One hard AI think. A mob resting (`MobState.thinking?/2`) or casting does
  # nothing; the think stamps its time so the lazy AI stays off for 200 ms. A
  # status-locked mob drops its target and attacked event and does nothing
  # else. Otherwise a standing mob checks its skills first (in the attack
  # state once its attack delay has ended, else once per skill interval): a
  # pick starts a cast (locking the mob until {:casting, :complete}) or fires
  # it instantly, and ends the think. Then the AI body runs, with the
  # rude-attacked event use fired from its target-change step. The very first
  # think after spawn selects with the :spawn event so `onspawn` rows can fire.
  # `now` is System.system_time(:millisecond), the same clock the melee path
  # uses for last_attack_time, so cooldown expiry lines up.
  defp think(state) do
    now = System.system_time(:millisecond)

    cond do
      not MobState.thinking?(state, now) ->
        state

      state.casting != nil ->
        %{state | next_think_at: now}

      StatusInterpreter.loses_target?(:mob, state.instance_id) ->
        %{state | next_think_at: now, loot_target_id: nil}
        |> MobState.set_target(nil)
        |> MobState.clear_attacked()

      true ->
        state = %{state | next_think_at: now}

        with {:none, state} <- spawn_event(state, now),
             {:none, state} <- skill_check(state, now) do
          AIStateMachine.process_ai(state, now,
            on_rude: &(&1 |> use_skill(:rudeattacked, now) |> elem(1))
          )
        else
          {:used, state} -> state
        end
    end
  end

  defp spawn_event(%MobState{spawn_tick_pending?: true} = state, now),
    do: use_skill(%{state | spawn_tick_pending?: false}, :spawn, now)

  defp spawn_event(state, _now), do: {:none, state}

  defp skill_check(%MobState{movement_state: :moving} = state, _now), do: {:none, state}

  defp skill_check(state, now) do
    ready? =
      case state.skill_state do
        :berserk -> AIStateMachine.attack_delay_over?(state, now)
        _other -> state.last_skillcheck == nil or now - state.last_skillcheck >= @skill_interval
      end

    if ready?, do: use_skill(state, :tick, now), else: {:none, state}
  end

  @npc_speedup 332
  @npc_emotions [197, 474]

  @doc """
  The skill check a walking mob makes before each cell, its first included:
  once more than the skill interval less half the walk speed has passed since
  the last periodic check, a mob not casting runs the periodic skill use.
  `{:stop, state}` when a skill was used and stops the walk: anything but
  Speed Up while the trick cast is kept or an emotion, unless the mob is in
  its walk state; `{:continue, state}` otherwise.
  """
  @spec walk_skill_check(MobState.t()) :: {:continue | :stop, MobState.t()}
  def walk_skill_check(%MobState{casting: nil, is_dead: false} = state) do
    now = System.system_time(:millisecond)

    if state.last_skillcheck == nil or
         now - state.last_skillcheck > @skill_interval - div(state.calculated.speed, 2) do
      case use_skill(state, :tick, now) do
        {:used, state} -> {if(keeps_walking?(state), do: :continue, else: :stop), state}
        {:none, state} -> {:continue, state}
      end
    else
      {:continue, state}
    end
  end

  def walk_skill_check(state), do: {:continue, state}

  defp keeps_walking?(%MobState{last_skill_id: @npc_speedup, trickcasting: until})
       when until != nil,
       do: true

  defp keeps_walking?(%MobState{last_skill_id: skill_id}) when skill_id in @npc_emotions,
    do: true

  defp keeps_walking?(%MobState{skill_state: skill_state}), do: skill_state == :walk

  # A periodic skill check (not an event use) stamps `last_skillcheck`.
  defp use_skill(state, event, now) do
    state = if event == :tick, do: %{state | last_skillcheck: now}, else: state

    case MobSkillSelector.select(state, MobSkillDb.rows_for(state.mob_id), now: now, event: event) do
      {:cast, row} -> state |> consume_rude_attacks(row, event) |> start_selected_skill(row, now)
      nil -> {:none, state}
    end
  end

  # A periodic pick of a rude-attacked row consumes the rude-attack count.
  defp consume_rude_attacks(state, %{condition: %{type: :rudeattacked}}, :tick),
    do: %{state | attacked_count: 0}

  defp consume_rude_attacks(state, _row, _event), do: state

  defp start_selected_skill(state, row, now) do
    if StatusInterpreter.can_use_skill?(:mob, state.instance_id, row.skill_id) do
      case CastingHandler.begin_cast(state, row, now) do
        {:ok, updated} -> {:used, updated}
        {:rejected, unchanged} -> {:none, unchanged}
      end
    else
      {:none, state}
    end
  end
end
