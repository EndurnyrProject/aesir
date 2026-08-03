defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler do
  @moduledoc """
  Applies combat and resource effects to the Homunculus nested in its owner session.

  This module never contacts the owner process. External delivery reaches it
  through `CommandHandler`; aggregate-local callers invoke it directly with the
  current `SessionState`.
  """

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.UnitHp
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @type event ::
          {:apply_damage, pos_integer(), non_neg_integer(), map(), tuple() | nil}
          | {:apply_heal, pos_integer(), non_neg_integer(), tuple() | nil}
          | {:drain_sp, pos_integer(), non_neg_integer()}
          | {:basic_attack, pos_integer(), tuple()}
          | {:status_changed, pos_integer(), atom(), :applied | :tick | :expired}

  @doc "Applies one typed combat event through the owning aggregate."
  @spec handle(event(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, term(), SessionState.t()}
  def handle({:apply_damage, gid, damage, _hit_info, _attacker}, session)
      when is_integer(damage) and damage > 0 do
    case active_homunculus(session, gid) do
      {:ok, homunculus} ->
        new_hp = max(homunculus.hp - damage, 0)

        if new_hp == 0 do
          die(session)
        else
          updated = %{homunculus | hp: new_hp}
          notify_hp(updated)
          {:noreply, StateCommit.commit(session, updated)}
        end

      {:error, :stale_target} ->
        {:noreply, session}
    end
  end

  def handle({:apply_damage, _gid, _damage, _hit_info, _attacker}, session),
    do: {:noreply, session}

  def handle({:apply_heal, gid, amount, _source}, session)
      when is_integer(amount) and amount > 0 do
    case active_homunculus(session, gid) do
      {:ok, homunculus} ->
        updated = %{homunculus | hp: min(homunculus.hp + amount, homunculus.max_hp)}
        notify_hp(updated)
        {:noreply, StateCommit.commit(session, updated)}

      {:error, :stale_target} ->
        {:noreply, session}
    end
  end

  def handle({:apply_heal, _gid, _amount, _source}, session), do: {:noreply, session}

  def handle({:drain_sp, gid, amount}, session) when is_integer(amount) and amount > 0 do
    case active_homunculus(session, gid) do
      {:ok, homunculus} ->
        updated = %{homunculus | sp: max(homunculus.sp - amount, 0)}
        {:noreply, StateCommit.commit(session, updated)}

      {:error, :stale_target} ->
        {:noreply, session}
    end
  end

  def handle({:drain_sp, _gid, _amount}, session), do: {:noreply, session}

  def handle({:status_changed, gid, _status_id, _event}, session) do
    case active_homunculus(session, gid) do
      {:ok, homunculus} -> {:noreply, StateCommit.commit(session, homunculus)}
      {:error, :stale_target} -> {:noreply, session}
    end
  end

  def handle({:basic_attack, gid, target_ref}, session) do
    case active_homunculus(session, gid) do
      {:ok, homunculus} ->
        session =
          if homunculus.action_state == :casting,
            do: CastingHandler.cancel(session),
            else: session

        attacking = %{session.homunculus | action_state: :attacking, target: target_ref}
        session = StateCommit.commit(session, attacking)

        case AutoAttack.execute_homunculus_attack(attacking, target_ref) do
          {:local_effects, effects} ->
            effects
            |> apply_local_effects(session)
            |> finish_attack(gid)

          _result ->
            finish_attack({:noreply, session}, gid)
        end

      {:error, :stale_target} ->
        {:noreply, session}
    end
  end

  defp apply_local_effects(effects, session) do
    Enum.reduce_while(effects, {:noreply, session}, fn
      {:homunculus, event}, {:noreply, current} ->
        case handle(event, current) do
          {:noreply, updated} -> {:cont, {:noreply, updated}}
          {:stop, _reason, _state} = stop -> {:halt, stop}
        end
    end)
  end

  defp finish_attack({:stop, _reason, _session} = stop, _gid), do: stop

  defp finish_attack({:noreply, session}, gid) do
    case active_homunculus(session, gid) do
      {:ok, homunculus} ->
        idle = %{homunculus | action_state: :idle, target: nil}
        {:noreply, StateCommit.commit(session, idle)}

      {:error, :stale_target} ->
        {:noreply, session}
    end
  end

  defp die(%SessionState{} = session) do
    session = CastingHandler.cancel(session)
    old_runtime = session.homunculus_runtime

    case LifecycleHandler.die(session.homunculus, old_runtime, timer_cancel: fn _ -> :ok end) do
      {:ok, dead, runtime} -> persist_death(session, dead, runtime, old_runtime)
      {:error, reason} -> {:stop, {:homunculus_death_failed, reason}, session}
    end
  end

  defp persist_death(session, dead, runtime, old_runtime) do
    now_ms = Clock.now_ms()

    with %Homunculus{id: id} = row <-
           Persistence.load_for_character(session.game_state.character_id),
         true <- id == dead.id,
         {:ok, clocks} <- Clock.durable_snapshot(:dead, nil, dead.cooldowns, now_ms),
         attrs <-
           dead
           |> ProgressionHandler.persistence_attrs()
           |> Map.put(:active_remaining_ms, 0)
           |> Map.put(:cooldowns, clocks.cooldowns),
         {:ok, _row} <- Persistence.save_semantic(row, attrs) do
      Clock.cancel(old_runtime.active_expiry_timer_ref)
      {:noop, _dead, runtime} = HungerHandler.arm(dead, runtime)
      notify_hp(dead)

      session = %{session | homunculus_runtime: runtime}
      {:noreply, StateCommit.commit(session, dead)}
    else
      reason -> {:stop, {:homunculus_death_persistence_failed, reason}, session}
    end
  end

  defp active_homunculus(%SessionState{} = session, gid) do
    case session.homunculus do
      %HomunculusState{world_gid: ^gid, lifecycle: :active} = state -> {:ok, state}
      _other -> {:error, :stale_target}
    end
  end

  defp notify_hp(%HomunculusState{} = state) do
    Broadcast.to_in_range(
      state.map_name,
      state.x,
      state.y,
      Config.view_range(),
      %UnitHp{id: state.world_gid, hp: state.hp, max_hp: max(state.max_hp, 1)}
    )
  end
end
