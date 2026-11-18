defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipProcHandler do
  @moduledoc """
  Owns equipment autobonus generations and direct equip-status reconciliation
  inside the player's session process.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.Stats

  @doc """
  Activates an autobonus registration: runs its other script, marks it active
  under a fresh generation, and forces a full recalculation, whose equipment
  fold runs the bonus script (and queues its effects). The expiry message is
  tagged with the generation, so only the latest activation's expiry ends it.
  A pet registration's timer is also kept in the pet runtime, replacing (and
  cancelling) the previous activation's, so freeing the pet cancels it. A
  registration that changed source since the trigger was dispatched is a
  no-op.
  """
  @spec activate(SessionState.t(), Stats.autobonus_key(), Stats.autobonus_source_identity()) ::
          {:noreply, SessionState.t()}
  def activate(%{game_state: %{stats: stats}} = state, key, expected_source_identity) do
    case Map.fetch(stats.equip_autobonuses, key) do
      {:ok, %{source_identity: ^expected_source_identity} = registration} ->
        granted_skills = Stats.granted_skills(stats)
        generation = System.unique_integer([:monotonic, :positive])
        state = apply_effects(registration.secondary_effects, state, registration, key)
        stats = state.game_state.stats
        active = Map.put(stats.active_autobonuses, key, generation)
        stats = Stats.force_full_recalculation(%{stats | active_autobonuses: active})
        state = %{state | game_state: %{state.game_state | stats: stats}}
        state = recalculate_and_sync_skills(state, granted_skills)

        timer =
          Process.send_after(
            self(),
            {:equip_autobonus_expire, key, generation},
            registration.duration_ms
          )

        {:noreply, track_pet_timer(state, key, timer)}

      _stale_or_missing ->
        {:noreply, state}
    end
  end

  @doc """
  Ends the activation tagged `generation` with a forced full recalculation; a
  stale generation or a registration that is gone is a no-op.
  """
  @spec expire(SessionState.t(), Stats.autobonus_key(), pos_integer()) ::
          {:noreply, SessionState.t()}
  def expire(%{game_state: %{stats: stats}} = state, key, generation) do
    with {:ok, _registration} <- Map.fetch(stats.equip_autobonuses, key),
         ^generation <- Map.get(stats.active_autobonuses, key) do
      granted_skills = Stats.granted_skills(stats)
      active = Map.delete(stats.active_autobonuses, key)
      stats = Stats.force_full_recalculation(%{stats | active_autobonuses: active})
      state = %{state | game_state: %{state.game_state | stats: stats}}
      {:noreply, state |> untrack_pet_timer(key) |> recalculate_and_sync_skills(granted_skills)}
    else
      _stale_or_missing -> {:noreply, state}
    end
  end

  defp track_pet_timer(%{pet_runtime: runtime} = state, {:pet, _ordinal} = key, timer) do
    Clock.cancel(Map.get(runtime.autobonus_timers, key))
    timers = Map.put(runtime.autobonus_timers, key, timer)
    %{state | pet_runtime: %{runtime | autobonus_timers: timers}}
  end

  defp track_pet_timer(state, _key, _timer), do: state

  defp untrack_pet_timer(%{pet_runtime: runtime} = state, {:pet, _ordinal} = key) do
    timers = Map.delete(runtime.autobonus_timers, key)
    %{state | pet_runtime: %{runtime | autobonus_timers: timers}}
  end

  defp untrack_pet_timer(state, _key), do: state

  @doc """
  Performs the side effects an equipment fold queued from the active
  autobonus programs, in order. A started or ended status refreshes the
  owner through its own calculation flags, as any status change does.
  """
  @spec perform_restores(SessionState.t(), [EquipScript.effect()]) :: SessionState.t()
  def perform_restores(state, effects) do
    Enum.reduce(effects, state, fn
      {:status_start, status, duration, value}, state ->
        character_id = state.game_state.character_id

        params = [
          caster_id: character_id,
          val1: value,
          duration: duration,
          owner_refresh: :notify,
          no_tick_def: true
        ]

        case Interpreter.apply_status(:player, character_id, status, params) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "Active autobonus status #{status} rejected for player #{character_id}: " <>
                inspect(reason)
            )
        end

        state

      {:status_end, status}, state ->
        Interpreter.remove_status(:player, state.game_state.character_id, status,
          owner_refresh: :notify
        )

        state

      {:heal, hp, sp}, state ->
        {:noreply, state} = HealthHandler.apply_forced_heal(hp, sp, state)
        state
    end)
  end

  @doc "Reconciles changed inventory-derived status inputs without rebuilding unchanged equipment."
  @spec reconcile_inventory_change(SessionState.t()) :: {:noreply, SessionState.t()}
  def reconcile_inventory_change(%{game_state: %{stats: stats}} = state) do
    if state.applied_equip_statuses == stats.equip_statuses and
         state.applied_card_unequip_effects == stats.card_unequip_effects do
      {:noreply, state}
    else
      reconcile_statuses(state)
    end
  end

  @spec reconcile_statuses(SessionState.t()) :: {:noreply, SessionState.t()}
  def reconcile_statuses(%{game_state: game_state} = state) do
    character_id = game_state.character_id
    desired_statuses = game_state.stats.equip_statuses
    current_cleanups = game_state.stats.card_unequip_effects
    previous_granted_skills = Stats.granted_skills(game_state.stats)

    state =
      state.applied_card_unequip_effects
      |> removed_cleanups(current_cleanups)
      |> Enum.reduce(state, &apply_card_cleanup/2)

    state.applied_equip_statuses
    |> Map.keys()
    |> Enum.sort()
    |> Enum.each(&remove_equip_status(&1, character_id))

    desired_statuses
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.each(fn {status, {duration, value}} ->
      apply_equip_status(status, duration, value, character_id)
    end)

    state = %{
      state
      | applied_equip_statuses: desired_statuses,
        applied_card_unequip_effects: current_cleanups
    }

    {:noreply, recalculate_and_sync_skills(state, previous_granted_skills)}
  end

  defp removed_cleanups(previous, current) do
    previous
    |> Enum.reject(fn {key, cleanup} ->
      case Map.fetch(current, key) do
        {:ok, retained} -> Map.get(cleanup, :refine) == Map.get(retained, :refine)
        :error -> false
      end
    end)
    |> Enum.sort_by(fn {_key, cleanup} -> cleanup.source_order end)
  end

  defp apply_card_cleanup({_key, %{effects: effects}}, state) do
    Enum.reduce(effects, state, fn
      {:status_start, status, duration, value}, state ->
        apply_cleanup_status(status, duration, value, state.game_state.character_id)
        state

      {:status_end, status}, state ->
        remove_equip_status(status, state.game_state.character_id)
        state

      {:heal, hp, sp}, state ->
        {:noreply, state} = HealthHandler.apply_forced_heal(hp, sp, state)
        state
    end)
  end

  defp apply_cleanup_status(status, duration, value, character_id) do
    params =
      [
        caster_id: character_id,
        val1: value,
        duration: duration,
        owner_refresh: :defer,
        no_tick_def: true
      ]

    case Interpreter.apply_status(:player, character_id, status, params) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Card cleanup status #{status} rejected for player #{character_id}: #{inspect(reason)}"
        )
    end
  end

  defp remove_equip_status(status, character_id) do
    Interpreter.remove_status(:player, character_id, status, owner_refresh: :defer)
  end

  defp apply_equip_status(status, duration, value, character_id) do
    params =
      [
        caster_id: character_id,
        val1: value,
        duration: duration,
        owner_refresh: :defer,
        no_tick_def: true
      ]

    case Interpreter.apply_status(:player, character_id, status, params) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Equipment status #{status} rejected for player #{character_id}: #{inspect(reason)}"
        )
    end
  end

  defp apply_effects(effects, state, registration, key) do
    Enum.reduce(effects, state, fn
      {:status_start, status, duration, value}, state ->
        character_id = state.game_state.character_id

        params =
          [
            caster_id: character_id,
            val1: value,
            duration: duration,
            owner_refresh: :defer,
            no_tick_def: true
          ]

        case Interpreter.apply_status(:player, character_id, status, params) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "Equipment autobonus status #{status} rejected for source " <>
                "#{inspect(registration.source_identity)}, secondary proc key #{inspect(key)}: " <>
                inspect(reason)
            )
        end

        state

      {:status_end, status}, state ->
        Interpreter.remove_status(
          :player,
          state.game_state.character_id,
          status,
          owner_refresh: :defer
        )

        state

      {:heal, hp, sp}, state ->
        {:noreply, state} = HealthHandler.apply_forced_heal(hp, sp, state)
        state
    end)
  end

  defp recalculate_and_sync_skills(state, previous_granted_skills) do
    state = StatusManager.recalculate_after_status_change(state)

    if Stats.granted_skills(state.game_state.stats) != previous_granted_skills do
      MessageRouter.send_to(state.connection_pid, SkillListView.build(state.game_state))
    end

    state
  end
end
