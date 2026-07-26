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

  # AI tick interval in milliseconds
  @ai_tick_interval 1000

  @doc """
  Processes a periodic `{:ai, :tick}`: dead and dormant mobs drop it, a
  casting mob stays locked (aborting first if a status restriction landed
  mid-cast), and otherwise runs skill selection/AI and reschedules the next
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
        # Completion is driven by the separate {:casting, :complete} timer,
        # unless its current statuses deny the pending skill.
        if CastingHandler.cast_interrupted?(state) do
          {:noreply, schedule_ai_tick(CastingHandler.abort_cast(state))}
        else
          {:noreply, schedule_ai_tick(state)}
        end

      true ->
        updated_state = state |> run_skill_or_ai() |> schedule_ai_tick()
        {:noreply, updated_state}
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

  @doc """
  Sets the mob's AI target for an `{:ai, {:set_target, target_id}}` cast,
  entering combat if a target is given or returning to idle if cleared.
  """
  @spec handle_set_target(MobState.t(), integer() | nil) :: {:noreply, MobState.t()}
  def handle_set_target(state, target_id) do
    updated_state =
      state
      |> MobState.set_target(target_id)
      |> MobState.set_ai_state(if target_id, do: :combat, else: :idle)

    {:noreply, updated_state}
  end

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

  # Skill selection runs before the melee/movement state machine: a tick that
  # picks a row either starts a cast (locking the mob until {:casting, :complete})
  # or fires it instantly; only a nil selection falls through to the normal AI.
  # The very first tick after spawn selects with the :spawn event so `onspawn`
  # rows can fire. `now` is System.system_time(:millisecond), the same clock
  # the melee path uses for last_attack_time, so cooldown expiry lines up.
  defp run_skill_or_ai(state) do
    now = System.system_time(:millisecond)
    event = if state.spawn_tick_pending?, do: :spawn, else: :tick
    state = %{state | spawn_tick_pending?: false}

    case MobSkillSelector.select(state, MobSkillDb.rows_for(state.mob_id), now: now, event: event) do
      {:cast, row} ->
        start_selected_skill(state, row, now)

      nil ->
        process_ai(state)
    end
  end

  defp start_selected_skill(state, row, now) do
    if StatusInterpreter.can_use_skill?(:mob, state.instance_id, row.skill_id) do
      case CastingHandler.begin_cast(state, row, now) do
        {:ok, updated} -> updated
        {:rejected, unchanged} -> process_ai(unchanged)
      end
    else
      process_ai(state)
    end
  end
end
