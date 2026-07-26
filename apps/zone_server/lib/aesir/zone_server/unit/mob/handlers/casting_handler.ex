defmodule Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler do
  @moduledoc """
  Handles a mob's skill-cast lifecycle: starting a cast, resolving it on
  completion, and aborting it on a forced interrupt or a mid-cast status
  restriction. Extracted from MobSession to improve modularity and
  maintainability.

  Cross-references `Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler` to
  reschedule the AI tick after a cast resolves; `AiHandler` calls back into
  this module to start a cast and to gate/abort a locked AI tick.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor, as: MobSkillExecutor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc """
  Starts a cast for `row`, either firing instantly (0 cast time) or locking
  the mob and scheduling `{:casting, :complete}`.
  """
  @spec begin_cast(MobState.t(), map(), integer()) :: {:ok | :rejected, MobState.t()}
  def begin_cast(state, %{cast_time: 0} = row, now) do
    MobSkillExecutor.broadcast_casting(state, row)

    if can_use_skill?(state, row) do
      MobSkillExecutor.execute(state, row)
      {:ok, MobState.put_skill_cooldown(state, row.skill_id, now + row.delay)}
    else
      MobSkillExecutor.broadcast_cast_cancel(state)
      {:rejected, state}
    end
  end

  def begin_cast(state, row, now) do
    MobSkillExecutor.broadcast_casting(state, row)

    if can_use_skill?(state, row) do
      timer_ref = Process.send_after(self(), {:casting, :complete}, row.cast_time)

      casting = %{
        row: row,
        complete_at: now + row.cast_time,
        timer_ref: timer_ref
      }

      {:ok, MobState.set_casting(state, casting)}
    else
      MobSkillExecutor.broadcast_cast_cancel(state)
      {:rejected, state}
    end
  end

  @doc """
  Resolves a `{:casting, :complete}` timer firing: dead and no-longer-casting
  mobs drop it, a live cast either aborts when current statuses deny its skill
  (or its target is invalidated) or executes and writes its cooldown, then the
  AI tick is rescheduled either way.
  """
  @spec handle_cast_complete(MobState.t()) :: {:noreply, MobState.t()}
  def handle_cast_complete(%{is_dead: true} = state), do: {:noreply, state}

  def handle_cast_complete(%{casting: nil} = state), do: {:noreply, state}

  def handle_cast_complete(%{casting: %{row: row}} = state) do
    # A status may have landed via a plain apply with no status-change hook, so
    # this poll guarantees it cannot fire a newly denied skill. Target invalidation surfaces as
    # {:error, _} from the Executor - also a clean abort with no packet. The
    # cooldown is written in every case so an aborted cast cannot be instantly
    # re-rolled every tick.
    updated_state =
      if can_use_skill?(state, row) do
        MobSkillExecutor.execute(state, row)
        now = System.system_time(:millisecond)

        state
        |> MobState.put_skill_cooldown(row.skill_id, now + row.delay)
        |> MobState.clear_casting()
      else
        abort_cast(state)
      end

    if updated_state.ai_timer_ref, do: Process.cancel_timer(updated_state.ai_timer_ref)

    {:noreply, AiHandler.schedule_ai_tick(updated_state)}
  end

  @doc """
  Force-cancels the mob's in-flight cast for an `{:casting, :interrupt}` call
  and reports what was cancelled. See
  `Aesir.ZoneServer.Unit.Mob.MobSession.interrupt_cast/1` for the full
  contract.
  """
  @spec handle_interrupt_cast(MobState.t()) ::
          {:reply,
           {:ok, %{skill: String.t(), skill_id: integer(), level: pos_integer()}}
           | {:error, :not_casting}, MobState.t()}
  def handle_interrupt_cast(%{is_dead: true} = state) do
    # A dying mob keeps its cast descriptor (handle_death/2 does not clear it)
    # and its process lingers until :terminate, so guard the same way
    # {:casting, :complete} does rather than let a corpse report a live cast.
    {:reply, {:error, :not_casting}, state}
  end

  def handle_interrupt_cast(%{casting: nil} = state) do
    {:reply, {:error, :not_casting}, state}
  end

  def handle_interrupt_cast(%{casting: %{row: row}} = state) do
    identity = %{skill: row.skill, skill_id: row.skill_id, level: row.level}
    {:reply, {:ok, identity}, abort_cast(state)}
  end

  @doc """
  Resolves an `{:casting, {:status_changed, ...}}` notification by promptly
  interrupting a cast newly denied by the status interpreter.
  """
  @spec handle_status_changed(atom(), atom(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_status_changed(_status_id, _event, %{casting: %{row: row}} = state) do
    if can_use_skill?(state, row), do: {:noreply, state}, else: {:noreply, abort_cast(state)}
  end

  def handle_status_changed(_status_id, _event, state), do: {:noreply, state}

  @doc """
  Returns whether the pending cast is denied by the status interpreter.
  """
  @spec cast_interrupted?(MobState.t()) :: boolean()
  def cast_interrupted?(%{casting: %{row: row}} = state), do: not can_use_skill?(state, row)
  def cast_interrupted?(_state), do: false

  defp can_use_skill?(state, row) do
    StatusInterpreter.can_use_skill?(:mob, state.instance_id, row.skill_id)
  end

  @doc """
  Aborts an in-flight cast cleanly: cancels the pending `{:casting, :complete}`
  timer so a stale one cannot fire against a later cast, tears down the
  client's cast bar, writes the skill's delay cooldown (mirroring the
  target-invalidation abort so there is no instant re-roll), and clears the
  cast descriptor. No damage or effect fires. Every status restriction and
  forced interrupt funnels through here, so the CastCancel is
  unconditional.
  """
  @spec abort_cast(MobState.t()) :: MobState.t()
  def abort_cast(%{casting: %{row: row} = casting} = state) do
    case Map.get(casting, :timer_ref) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    MobSkillExecutor.broadcast_cast_cancel(state)

    now = System.system_time(:millisecond)

    state
    |> MobState.put_skill_cooldown(row.skill_id, now + row.delay)
    |> MobState.clear_casting()
  end
end
