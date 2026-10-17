defmodule Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler do
  @moduledoc """
  Handles a mob's skill-cast lifecycle: starting a cast, resolving it on
  completion, and aborting it on a forced interrupt or on active damage when
  its row is cancelable. A status that lands mid-cast does not interrupt it;
  the cast is judged when it completes. A cast's end and its cancel both start
  the mob's attack delay; a cast's end also rests its AI for its attack motion.
  Extracted from MobSession to improve modularity and maintainability.

  Cross-references `Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler` to
  reschedule the AI tick after a cast resolves; `AiHandler` calls back into
  this module to start a cast and to gate/abort a locked AI tick.
  """

  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor, as: MobSkillExecutor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc """
  Starts a cast for `row`, either firing instantly (0 cast time) or locking
  the mob and scheduling `{:casting, :complete}`. A status that denies the
  skill or a unit target concealed from the mob rejects the cast.
  """
  @spec begin_cast(MobState.t(), map(), integer()) :: {:ok | :rejected, MobState.t()}
  def begin_cast(state, %{cast_time: 0} = row, now) do
    MobSkillExecutor.broadcast_casting(state, row)

    if can_use_skill?(state, row) and target_reachable?(state, row) do
      state = state |> MobSkillExecutor.execute(row) |> executed_state(state)

      {:ok,
       %{state | last_skill_id: row.skill_id}
       |> MobState.put_skill_cooldown(row.skill_id, now + row.delay)
       |> start_attack_delay()
       |> MobState.rest(now)}
    else
      MobSkillExecutor.broadcast_cast_cancel(state)
      {:rejected, state}
    end
  end

  def begin_cast(state, row, now) do
    MobSkillExecutor.broadcast_casting(state, row)

    if can_use_skill?(state, row) and target_reachable?(state, row) do
      timer_ref = Process.send_after(self(), {:casting, :complete}, row.cast_time)

      casting = %{
        row: row,
        complete_at: now + row.cast_time,
        timer_ref: timer_ref
      }

      {:ok, MobState.set_casting(%{state | last_skill_id: row.skill_id}, casting)}
    else
      MobSkillExecutor.broadcast_cast_cancel(state)
      {:rejected, state}
    end
  end

  @doc """
  Resolves a `{:casting, :complete}` timer firing: dead and no-longer-casting
  mobs drop it, a live cast executes through the completion check and writes
  its cooldown, then the AI tick is rescheduled.
  """
  @spec handle_cast_complete(MobState.t()) :: {:noreply, MobState.t()}
  def handle_cast_complete(%{is_dead: true} = state), do: {:noreply, state}

  def handle_cast_complete(%{casting: nil} = state), do: {:noreply, state}

  def handle_cast_complete(%{casting: %{row: row}} = state) do
    # A caster that can no longer complete the cast, or an invalidated target,
    # surfaces as {:error, _} from the Executor: a clean abort with no packet.
    # The cooldown is written in every case so a failed cast cannot be
    # instantly re-rolled every tick.
    state = state |> MobSkillExecutor.execute(row, :cast_end) |> executed_state(state)
    now = System.system_time(:millisecond)

    updated_state =
      state
      |> MobState.put_skill_cooldown(row.skill_id, now + row.delay)
      |> MobState.clear_casting()
      |> start_attack_delay()
      |> MobState.rest(now)

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
  Cancels the in-flight cast on active damage (`DamageShared.active_damage?/1`
  over `damage_info`) when its row is cancelable, as `abort_cast/1` does.
  Anything else passes through unchanged.
  """
  @spec interrupt_on_damage(MobState.t(), map()) :: MobState.t()
  def interrupt_on_damage(%{casting: %{row: %{cancelable: true}}} = state, damage_info) do
    if DamageShared.active_damage?(damage_info), do: abort_cast(state), else: state
  end

  def interrupt_on_damage(state, _damage_info), do: state

  # A skill that changed its caster hands back the mob's new state.
  defp executed_state({:ok, %MobState{} = executed}, _state), do: executed
  defp executed_state(_result, state), do: state

  # The reference sets a monster's attack delay when a cast ends or is cancelled.
  defp start_attack_delay(state),
    do: %{state | last_attack_time: System.system_time(:millisecond)}

  defp can_use_skill?(state, row) do
    StatusInterpreter.can_use_skill?(:mob, state.instance_id, row.skill_id)
  end

  # A cast begins only against a unit target its caster can reach through the
  # target's concealment.
  defp target_reachable?(state, row),
    do: MobSkillExecutor.check_target(state, row, :cast_begin) == :ok

  @doc """
  Aborts an in-flight cast cleanly: cancels the pending `{:casting, :complete}`
  timer so a stale one cannot fire against a later cast, tears down the
  client's cast bar, writes the skill's delay cooldown (mirroring the
  completion path so there is no instant re-roll), and clears the cast
  descriptor and starts the attack delay. No damage or effect fires. Every
  forced interrupt funnels through here, so the CastCancel is unconditional.
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
    |> start_attack_delay()
  end
end
