defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler do
  @moduledoc """
  Runs Homunculus skills inside the owning player aggregate.

  Cast identity is the pair of an immutable token stored on the Homunculus and
  the OTP timer reference stored in `Runtime`. Completion must match both and
  then revalidates the latest caster and target through `Skill.Interpreter`.
  """

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ItemEffectHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @type begin_result ::
          {:ok, SessionState.t()}
          | {:error, term(), SessionState.t()}
          | {:stop, term(), SessionState.t()}

  @doc "Begins the shared manual/AI cast path and schedules a timed cast when required."
  @spec begin(SessionState.t(), integer(), pos_integer(), Active.target()) :: begin_result()
  def begin(%SessionState{} = session, id, level, target) do
    case session.homunculus do
      %HomunculusState{} = homunculus -> begin_current(session, homunculus, id, level, target)
      nil -> {:error, :no_homunculus, session}
    end
  end

  @doc "Completes only the current immutable cast token and OTP timer reference."
  @spec complete(reference(), reference(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def complete(timer_ref, token, %SessionState{} = session)
      when is_reference(timer_ref) and is_reference(token) do
    case current_cast(session, timer_ref, token) do
      {:ok, homunculus, casting} -> complete_current(session, homunculus, casting)
      :stale -> {:noreply, session}
    end
  end

  def complete(_timer_ref, _token, %SessionState{} = session), do: {:noreply, session}

  @doc "Resolves only the current Bio Explosion timer against the same live world identity."
  @spec resolve_bio_explosion(reference(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def resolve_bio_explosion(ref, %SessionState{} = session) when is_reference(ref) do
    runtime = session.homunculus_runtime

    if Clock.current_timer?(runtime.bio_explosion_timer_ref, ref) do
      descriptor = runtime.bio_explosion_descriptor

      session = %{
        session
        | homunculus_runtime: %{
            runtime
            | bio_explosion_timer_ref: nil,
              bio_explosion_descriptor: nil
          }
      }

      resolve_current_bio_explosion(session, descriptor)
    else
      {:noreply, session}
    end
  end

  @doc "Cancels a pending Bio Explosion without changing its settled costs."
  @spec cancel_bio_explosion(SessionState.t()) :: SessionState.t()
  def cancel_bio_explosion(%SessionState{} = session) do
    runtime = Clock.cancel_field(session.homunculus_runtime, :bio_explosion_timer_ref)
    %{session | homunculus_runtime: %{runtime | bio_explosion_descriptor: nil}}
  end

  @doc "Cancels the current cast without settling SP or cooldown."
  @spec cancel(SessionState.t()) :: SessionState.t()
  def cancel(%SessionState{} = session) do
    Clock.cancel(session.homunculus_runtime.cast_timer_ref)
    session = clear_runtime_cast(session)

    case session.homunculus do
      %HomunculusState{casting: casting} = homunculus when not is_nil(casting) ->
        StateCommit.commit(session, %{homunculus | action_state: :idle, casting: nil})

      _other ->
        session
    end
  end

  defp begin_current(session, _homunculus, _id, _level, _target)
       when not is_nil(session.homunculus_runtime.bio_explosion_timer_ref),
       do: {:error, :bio_explosion_pending, session}

  defp begin_current(session, homunculus, id, level, target) do
    case Interpreter.begin_cast(homunculus, id, level, target) do
      {:instant, updated} -> finish(session, updated, [])
      {:instant, updated, effects} -> finish(session, updated, effects)
      {:casting, updated, info} -> schedule(session, updated, info)
      {:error, reason} -> {:error, reason, session}
    end
  end

  defp complete_current(session, homunculus, casting) do
    case Interpreter.complete_cast(
           homunculus,
           casting.skill_id,
           casting.level,
           casting.target
         ) do
      {:ok, updated} -> finish_completed(session, updated, [])
      {:local_effects, updated, effects} -> finish_completed(session, updated, effects)
      {:error, _reason} -> {:noreply, cancel(session)}
    end
  end

  defp finish_completed(session, updated, effects) do
    cleared = clear_runtime_cast(session)
    updated = %{updated | action_state: :idle, casting: nil}

    case finish(cleared, updated, effects) do
      {:ok, completed} -> {:noreply, completed}
      {:error, _reason, restored} -> {:noreply, cancel(restored)}
      {:stop, _reason, _state} = stop -> stop
    end
  end

  defp current_cast(session, timer_ref, token) do
    case {session.homunculus, session.homunculus_runtime.cast_timer_ref} do
      {%HomunculusState{casting: %{token: ^token} = casting} = homunculus, ^timer_ref} ->
        {:ok, homunculus, casting}

      _other ->
        :stale
    end
  end

  defp schedule(session, homunculus, info) do
    token = make_ref()
    timer_ref = Clock.arm(info.total, {:cast_complete, token})

    casting = %{
      token: token,
      skill_id: info.skill_id,
      level: info.level,
      target: info.target,
      fixed: info.fixed,
      total: info.total
    }

    runtime = %{session.homunculus_runtime | cast_timer_ref: timer_ref}
    homunculus = %{homunculus | action_state: :casting, casting: casting}
    session = %{session | homunculus_runtime: runtime}
    {:ok, StateCommit.commit(session, homunculus)}
  end

  defp finish(
         session,
         homunculus,
         [{:owner_item_cost, item_id, amount} | effects]
       )
       when is_integer(item_id) and item_id > 0 and is_integer(amount) and amount > 0 do
    case ItemEffectHandler.settle_skill_cost(session, homunculus, item_id, amount) do
      {:ok, settled, index} ->
        finish_with_item_cost(settled, homunculus, effects, index, amount)

      {:error, reason} ->
        {:error, reason, session}
    end
  end

  defp finish(session, homunculus, effects) do
    case bio_explosion_descriptor(effects) do
      {:ok, descriptor} ->
        finish_bio_explosion(session, homunculus, descriptor)

      :none ->
        case persist_intimacy_change(session, homunculus) do
          :ok -> finish_committed(session, homunculus, effects)
          {:error, reason} -> {:error, reason, session}
        end
    end
  end

  defp finish_bio_explosion(session, homunculus, descriptor) do
    cond do
      not is_nil(session.homunculus_runtime.bio_explosion_timer_ref) ->
        {:error, :bio_explosion_pending, session}

      homunculus.intimacy_hundredths < descriptor.required_intimacy ->
        {:error, :insufficient_intimacy, session}

      true ->
        settled = %{homunculus | intimacy_hundredths: descriptor.reset_intimacy}

        case persist_bio_explosion(session, settled) do
          :ok -> execute_and_arm_bio_explosion(session, settled, descriptor)
          {:error, _reason} -> {:error, :bio_explosion_settlement_failed, session}
        end
    end
  end

  defp finish_committed(session, homunculus, effects) do
    session
    |> rearm_cooldown(homunculus)
    |> StateCommit.commit(homunculus)
    |> then(&CommandHandler.local_effects(effects, &1))
    |> case do
      {:noreply, completed} ->
        {:ok, completed}

      {:error, reason, _unchanged} ->
        {:error, reason, restore_failed_local_effect(session)}

      {:stop, _reason, _state} = stop ->
        stop
    end
  end

  defp finish_with_item_cost(session, homunculus, effects, index, amount) do
    committed = session |> rearm_cooldown(homunculus) |> StateCommit.commit(homunculus)
    :ok = ItemEffectHandler.publish_skill_cost(committed, index, amount)

    case CommandHandler.local_effects(effects, committed) do
      {:noreply, completed} -> {:ok, completed}
      {:stop, _reason, _state} = stop -> stop
    end
  end

  defp persist_intimacy_change(session, homunculus) do
    if session.homunculus.intimacy_hundredths == homunculus.intimacy_hundredths do
      :ok
    else
      persist_changed_intimacy(session, homunculus.intimacy_hundredths)
    end
  end

  defp persist_changed_intimacy(session, intimacy) do
    owner_id = session.game_state.character_id
    homunculus_id = session.homunculus.id

    case Persistence.load_for_character(owner_id) do
      %{id: ^homunculus_id} = row ->
        case Persistence.save_semantic(row, %{intimacy_hundredths: intimacy}) do
          {:ok, _row} -> :ok
          {:error, reason} -> {:error, reason}
        end

      nil ->
        {:error, :homunculus_not_found}

      _other ->
        {:error, :homunculus_id_mismatch}
    end
  end

  defp restore_failed_local_effect(session) do
    private_dirty = session.homunculus_runtime.private_dirty
    session = rearm_cooldown(session, session.homunculus)
    session = StateCommit.commit(session, session.homunculus)
    runtime = %{session.homunculus_runtime | private_dirty: private_dirty}
    %{session | homunculus_runtime: runtime}
  end

  defp bio_explosion_descriptor(effects) do
    case Enum.find(effects, fn
           {:homunculus, {:schedule_bio_explosion, %{kind: :bio_explosion}}} -> true
           _effect -> false
         end) do
      {:homunculus, {:schedule_bio_explosion, descriptor}} -> {:ok, descriptor}
      nil -> :none
    end
  end

  defp persist_bio_explosion(session, homunculus) do
    now_ms = Clock.now_ms()

    with %Homunculus{id: id} = row <-
           Persistence.load_for_character(homunculus.owner_character_id),
         true <- id == homunculus.id,
         {:ok, clocks} <-
           Clock.durable_snapshot(
             homunculus.lifecycle,
             session.homunculus_runtime.active_deadline_ms,
             homunculus.cooldowns,
             now_ms
           ),
         attrs <-
           homunculus
           |> ProgressionHandler.persistence_attrs()
           |> Map.put(:active_remaining_ms, clocks.active_remaining_ms)
           |> Map.put(:cooldowns, clocks.cooldowns),
         {:ok, _row} <- Persistence.save_semantic(row, attrs) do
      :ok
    else
      false -> {:error, :durable_state_mismatch}
      nil -> {:error, :homunculus_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_current_bio_explosion(%SessionState{} = session, descriptor) do
    case {session.homunculus, descriptor} do
      {%HomunculusState{} = homunculus,
       %{
         kind: :bio_explosion,
         homunculus_id: id,
         world_gid: gid,
         map_name: map_name,
         lifecycle: lifecycle,
         skill_id: skill_id
       }}
      when homunculus.id == id and homunculus.world_gid == gid and
             homunculus.map_name == map_name and homunculus.lifecycle == lifecycle ->
        if HomunculusState.living?(homunculus) do
          CombatHandler.handle(
            {:apply_damage, gid, homunculus.hp, %{skill_id: skill_id}, {:homunculus, gid}},
            session
          )
        else
          {:noreply, session}
        end

      _stale ->
        {:noreply, session}
    end
  end

  defp execute_and_arm_bio_explosion(session, homunculus, descriptor) do
    session =
      session
      |> rearm_cooldown(homunculus)
      |> StateCommit.commit(homunculus)

    Combat.execute_misc_splash(homunculus, descriptor.center, descriptor.radius,
      skill_id: descriptor.skill_id,
      skill_level: descriptor.skill_level,
      base_damage: descriptor.base_damage,
      element: :neutral,
      ignore_element: descriptor.ignore_element,
      target_skill_units: descriptor.target_skill_units,
      shoot_range_los: descriptor.shoot_range_los
    )

    runtime = session.homunculus_runtime
    ref = Clock.arm(descriptor.delay_ms, :bio_explosion)

    death_descriptor =
      Map.take(descriptor, [
        :kind,
        :homunculus_id,
        :world_gid,
        :map_name,
        :lifecycle,
        :skill_id
      ])

    completed = %{
      session
      | homunculus_runtime: %{
          runtime
          | bio_explosion_timer_ref: ref,
            bio_explosion_descriptor: death_descriptor
        }
    }

    {:ok, completed}
  end

  defp rearm_cooldown(session, homunculus) do
    Clock.cancel(session.homunculus_runtime.cooldown_timer_ref)
    now = Clock.now_ms()
    ref = Clock.arm_nearest_cooldown(homunculus.cooldowns, now)
    %{session | homunculus_runtime: %{session.homunculus_runtime | cooldown_timer_ref: ref}}
  end

  defp clear_runtime_cast(session) do
    %{session | homunculus_runtime: %{session.homunculus_runtime | cast_timer_ref: nil}}
  end
end
