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
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.PotionRecovery
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @type event ::
          {:apply_damage, pos_integer(), non_neg_integer(), map(), tuple() | nil}
          | {:apply_heal, pos_integer(), DamageApplication.heal_amount(), tuple() | nil}
          | {:drain_sp, pos_integer(), non_neg_integer()}
          | {:basic_attack, pos_integer(), tuple()}
          | {:status_changed, pos_integer(), atom(), :applied | :tick | :expired | :removed}

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

  # Renewal's three-times Homunculus bonus applies only to HP potion recovery; SP uses shared recovery unmultiplied.
  def handle({:apply_heal, gid, {:potion, :hp, _amount} = descriptor, _source}, session) do
    case active_homunculus(session, gid) do
      {:ok, homunculus} ->
        amount = PotionRecovery.recover(descriptor, potion_recipient_terms(homunculus)) * 3
        updated = %{homunculus | hp: min(homunculus.hp + amount, homunculus.max_hp)}
        notify_hp(updated)
        {:noreply, StateCommit.commit(session, updated)}

      {:error, :stale_target} ->
        {:noreply, session}
    end
  end

  def handle({:apply_heal, gid, {:potion, :sp, _amount} = descriptor, _source}, session) do
    case active_homunculus(session, gid) do
      {:ok, homunculus} ->
        amount = PotionRecovery.recover(descriptor, potion_recipient_terms(homunculus))
        updated = %{homunculus | sp: min(homunculus.sp + amount, homunculus.max_sp)}
        {:noreply, StateCommit.commit(session, updated)}

      {:error, :stale_target} ->
        {:noreply, session}
    end
  end

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

  def handle({:status_changed, gid, status_id, event}, session) do
    case active_homunculus(session, gid) do
      {:ok, homunculus} -> refresh_status(session, homunculus, status_id, event)
      {:error, :stale_target} -> {:noreply, session}
    end
  end

  def handle({:basic_attack, gid, target_ref}, session) do
    now_ms = System.monotonic_time(:millisecond)

    with {:ok, homunculus} <- active_homunculus(session, gid),
         true <- basic_attack_ready?(session.homunculus_runtime, homunculus, now_ms) do
      runtime = %{session.homunculus_runtime | last_basic_attack_at_ms: now_ms}
      session = %{session | homunculus_runtime: runtime}

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
    else
      _not_ready_or_stale -> {:noreply, session}
    end
  end

  @doc false
  @spec basic_attack_ready?(map(), HomunculusState.t(), integer()) :: boolean()
  def basic_attack_ready?(runtime, %HomunculusState{} = homunculus, now_ms) do
    case runtime.last_basic_attack_at_ms do
      nil -> true
      last_at -> now_ms - last_at >= homunculus.attack_delay_ms
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

  defp refresh_status(session, homunculus, :sc_change, :expired) do
    if lif?(homunculus) do
      recomputed = recompute_statuses(homunculus)
      changed = %{recomputed | hp: 10, sp: 10}

      case persist_resources(changed) do
        :ok ->
          notify_hp(changed)
          {:noreply, StateCommit.commit(session, changed)}

        {:error, reason} ->
          {:stop, {:homunculus_change_expiry_persistence_failed, reason}, session}
      end
    else
      commit_recomputed(session, homunculus)
    end
  end

  defp refresh_status(session, homunculus, _status_id, _event),
    do: commit_recomputed(session, homunculus)

  defp commit_recomputed(session, homunculus) do
    recomputed = recompute_statuses(homunculus)
    notify_hp(recomputed)
    {:noreply, StateCommit.commit(session, recomputed)}
  end

  defp recompute_statuses(%HomunculusState{} = homunculus) do
    modifiers =
      ModifierCalculator.get_all_modifiers(:homunculus, homunculus.world_gid)

    Stats.recompute(homunculus, modifiers)
  end

  defp lif?(%HomunculusState{} = homunculus) do
    case Catalog.by_id(homunculus.class_id) do
      {:ok, %{base_class_id: base_class_id}} -> base_class_id in [6001, 6005]
      :error -> false
    end
  end

  defp persist_resources(%HomunculusState{} = homunculus) do
    case Persistence.load_for_character(homunculus.owner_character_id) do
      %Homunculus{id: id} = row when id == homunculus.id ->
        case Persistence.checkpoint(row, %{hp: homunculus.hp, sp: homunculus.sp}) do
          {:ok, _row} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _missing ->
        {:error, :not_persisted}
    end
  end

  defp die(%SessionState{} = session) do
    session =
      session
      |> CastingHandler.cancel()
      |> CastingHandler.cancel_bio_explosion()
      |> AiHandler.cancel()
      |> MovementHandler.cancel()

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

  defp potion_recipient_terms(%HomunculusState{} = homunculus) do
    %{
      learning_potion: 0,
      effective_vit: homunculus.vit,
      effective_int: homunculus.int,
      item_heal_rate: 0
    }
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
