defmodule Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler do
  @moduledoc """
  Handles a mob's skill-cast lifecycle: starting a cast, resolving it on
  completion, and aborting it on a forced interrupt or a mid-cast
  silence/stun. Extracted from MobSession to improve modularity and
  maintainability.

  Cross-references `Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler` to
  reschedule the AI tick after a cast resolves; `AiHandler` calls back into
  this module to start a cast and to gate/abort a locked AI tick.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor, as: MobSkillExecutor
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc """
  Starts a cast for `row`, either firing instantly (0 cast time) or locking
  the mob and scheduling `:cast_complete`.
  """
  @spec begin_cast(MobState.t(), map(), integer()) :: MobState.t()
  def begin_cast(state, %{cast_time: 0} = row, now) do
    MobSkillExecutor.broadcast_casting(state, row)
    MobSkillExecutor.execute(state, row)
    MobState.put_skill_cooldown(state, row.skill, now + row.delay)
  end

  def begin_cast(state, row, now) do
    MobSkillExecutor.broadcast_casting(state, row)
    timer_ref = Process.send_after(self(), :cast_complete, row.cast_time)

    MobState.set_casting(state, %{
      row: row,
      complete_at: now + row.cast_time,
      timer_ref: timer_ref
    })
  end

  @doc """
  Resolves a `:cast_complete` timer firing: dead and no-longer-casting mobs
  drop it, a live cast either aborts (silence/stun landed without the
  `:status_changed` hook, or the target invalidated) or executes and writes
  its cooldown, then the AI tick is rescheduled either way.
  """
  @spec handle_cast_complete(MobState.t()) :: {:noreply, MobState.t()}
  def handle_cast_complete(%{is_dead: true} = state), do: {:noreply, state}

  def handle_cast_complete(%{casting: nil} = state), do: {:noreply, state}

  def handle_cast_complete(%{casting: %{row: row}} = state) do
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

    {:noreply, AiHandler.schedule_ai_tick(updated_state)}
  end

  @doc """
  Force-cancels the mob's in-flight cast for a `:interrupt_cast` call and
  reports what was cancelled. See `Aesir.ZoneServer.Unit.Mob.MobSession.interrupt_cast/1`
  for the full contract.
  """
  @spec handle_interrupt_cast(MobState.t()) ::
          {:reply,
           {:ok, %{skill: String.t(), skill_id: integer(), level: pos_integer()}}
           | {:error, :not_casting}, MobState.t()}
  def handle_interrupt_cast(%{is_dead: true} = state) do
    # A dying mob keeps its cast descriptor (handle_death/2 does not clear it)
    # and its process lingers until :terminate, so guard the same way
    # :cast_complete does rather than let a corpse report a live cast.
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
  Resolves a `:status_changed` notification: a silence/stun landing mid-cast
  aborts it promptly, any other status is a no-op here.
  """
  @spec handle_status_changed(atom(), atom(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_status_changed(status_id, _event, %{casting: casting} = state)
      when status_id in [:sc_silence, :sc_stun] and casting != nil do
    # A silence/stun tick landing mid-cast aborts it promptly. The live
    # :cast_complete poll is the authoritative guarantee (a status can be applied
    # without ever emitting this hook); this only shortens the interruption
    # latency when the hook does fire. A live :ai_tick timer keeps AI going.
    {:noreply, abort_cast(state)}
  end

  def handle_status_changed(_status_id, _event, state) do
    # Fired by StatusTickManager when one of this mob's statuses ticks or expires.
    # Combat stats are folded live on read (MobState.to_combatant/1) and the
    # icon/opt display delta is already broadcast by the StatusEffect.Interpreter,
    # so there is nothing to recompute here.
    {:noreply, state}
  end

  @doc """
  A silence or stun on this mob interrupts skill casting (melee/movement are
  gated separately by the status interpreter).
  """
  @spec cast_interrupted?(MobState.t()) :: boolean()
  def cast_interrupted?(state) do
    StatusStorage.has_status?(:mob, state.instance_id, :sc_silence) or
      StatusStorage.has_status?(:mob, state.instance_id, :sc_stun)
  end

  @doc """
  Aborts an in-flight cast cleanly: cancels the pending :cast_complete timer so
  a stale one cannot fire against a later cast, tears down the client's cast
  bar, writes the skill's delay cooldown (mirroring the target-invalidation
  abort so there is no instant re-roll), and clears the cast descriptor. No
  damage or effect fires. Every abort path (silence/stun and the forced
  interrupt_cast/1) funnels through here, so the CastCancel is unconditional.
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
    |> MobState.put_skill_cooldown(row.skill, now + row.delay)
    |> MobState.clear_casting()
  end
end
