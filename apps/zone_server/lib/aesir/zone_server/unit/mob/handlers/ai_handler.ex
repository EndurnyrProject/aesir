defmodule Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler do
  @moduledoc """
  Handles a mob's AI loop: the periodic `{:ai, :tick}`, sleep/wake suspension
  of the loop while its map has no players, and AI target assignment.
  Extracted from MobSession to improve modularity and maintainability.

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
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # AI tick interval in milliseconds
  @ai_tick_interval 1000

  @doc """
  Processes a periodic `{:ai, :tick}`: dead and dormant mobs drop it, a
  casting mob stays locked, a resting mob (`MobState.thinking?/2`) waits until
  its rest ends, and otherwise runs skill selection/AI and reschedules the next
  tick.
  """
  @spec handle_ai_tick(MobState.t()) :: {:noreply, MobState.t()}
  def handle_ai_tick(state) do
    cond do
      state.is_dead ->
        # Dead mobs don't process AI
        {:noreply, state}

      not state.ai_awake ->
        # A tick that raced a {:ai, :sleep}; drop it without rescheduling
        {:noreply, state}

      state.casting != nil ->
        # A casting mob is locked: no movement, no melee, no re-selection.
        # Completion is driven by the separate {:casting, :complete} timer.
        {:noreply, schedule_ai_tick(state)}

      not MobState.thinking?(state, System.system_time(:millisecond)) ->
        # Resting after an attack or a cast's end: think again once it passes.
        rest = state.next_think_at - System.system_time(:millisecond)
        {:noreply, schedule_ai_tick(state, min(max(rest, 1), @ai_tick_interval))}

      true ->
        updated_state = state |> think() |> schedule_ai_tick()
        {:noreply, updated_state}
    end
  end

  @doc """
  Processes an `{:ai, {:attacked, attacker_ref, norm?}}` event, the end of a
  landed hit's walk delay: stores the retaliation target (a slave's or a
  player summon's master, else the attacker) as the pending attacked event,
  leaves the aggressive mode, and thinks at once through the same gates as a
  tick, without moving the tick schedule. A dormant mob wakes its AI loop, so
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

        if think_now?(state),
          do: {:noreply, think(state)},
          else: {:noreply, state}
    end
  end

  defp wake_for_attacked(%MobState{ai_awake: false, is_dead: false} = state),
    do: schedule_ai_tick(%{state | ai_awake: true})

  defp wake_for_attacked(state), do: state

  defp think_now?(state) do
    not state.is_dead and is_nil(state.casting) and
      MobState.thinking?(state, System.system_time(:millisecond))
  end

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
      |> MobState.set_target(nil)
      |> MobState.set_ai_state(:idle)
      |> Map.merge(%{ai_awake: false, ai_timer_ref: nil})

    {:noreply, updated_state, :hibernate}
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
    updated =
      state
      |> MobState.set_target(new_ref)
      |> MobState.set_ai_state(:combat)

    {:reply, :ok, updated}
  end

  def handle_redirect_target(%MobState{is_dead: true} = state, _expected_ref, _new_ref),
    do: {:reply, {:error, :dead}, state}

  def handle_redirect_target(%MobState{} = state, _expected_ref, _new_ref),
    do: {:reply, {:error, :target_changed}, state}

  @doc """
  Sets the mob's typed AI target for an `{:ai, {:set_target, target_ref}}` cast,
  entering combat if a target is given or returning to idle if cleared.
  """
  @spec handle_set_target(MobState.t(), tuple() | integer() | nil) :: {:noreply, MobState.t()}
  def handle_set_target(state, target_ref) do
    updated_state =
      state
      |> MobState.set_target(target_ref)
      |> MobState.set_ai_state(if target_ref, do: :combat, else: :idle)

    {:noreply, updated_state}
  end

  @doc """
  Attacks `target_ref` once for an `{:attack_intent, ref}` nudge (Poison
  React's counter) without changing the mob's target; dead mobs ignore it.
  """
  @spec handle_attack_intent(MobState.t(), tuple()) :: {:noreply, MobState.t()}
  def handle_attack_intent(%MobState{is_dead: true} = state, _target_ref), do: {:noreply, state}

  def handle_attack_intent(%MobState{} = state, target_ref),
    do: {:noreply, AIStateMachine.attack_once(state, target_ref)}

  @doc """
  Schedules the next `{:ai, :tick}` after `interval` milliseconds (defaults to
  the tick interval), stamping the new timer ref on the state.
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

  defp process_ai(state) do
    AIStateMachine.process_ai(state)
  end

  # One AI think. A status-locked mob drops its target and attacked event and
  # does nothing else. Otherwise skill selection runs first: a tick that picks a
  # row starts a cast (locking the mob until {:casting, :complete}) or fires it
  # instantly, and ends the think. Then the target-change step consumes a
  # pending attacked event, possibly firing the rude-attacked event use, and
  # the state machine runs its step. The very first think after spawn selects
  # with the :spawn event so `onspawn` rows can fire. `now` is
  # System.system_time(:millisecond), the same clock the melee path uses for
  # last_attack_time, so cooldown expiry lines up.
  defp think(state) do
    if StatusInterpreter.loses_target?(:mob, state.instance_id) do
      state |> MobState.set_target(nil) |> MobState.clear_attacked()
    else
      now = System.system_time(:millisecond)
      event = if state.spawn_tick_pending?, do: :spawn, else: :tick

      case use_skill(%{state | spawn_tick_pending?: false}, event, now) do
        {:used, state} -> state
        {:none, state} -> state |> AIStateMachine.process_attacked() |> after_attacked(now)
      end
    end
  end

  defp after_attacked({state, true}, now) do
    case use_skill(state, :rudeattacked, now) do
      {:used, state} -> state
      {:none, state} -> process_ai(state)
    end
  end

  defp after_attacked({state, false}, _now), do: process_ai(state)

  defp use_skill(state, event, now) do
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
