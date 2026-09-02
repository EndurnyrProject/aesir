defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipProcHandler do
  @moduledoc """
  Owns equipment autobonus generations and direct equip-status reconciliation
  inside the player's session process.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.Stats

  @spec activate(SessionState.t(), Stats.autobonus_key()) :: {:noreply, SessionState.t()}
  def activate(%{game_state: %{stats: stats}} = state, key) do
    case Map.fetch(stats.equip_autobonuses, key) do
      {:ok, registration} ->
        granted_skills = Stats.granted_skills(stats)
        generation = System.unique_integer([:monotonic, :positive])
        active = Map.put(stats.active_autobonuses, key, generation)
        stats = %{stats | active_autobonuses: active}
        state = %{state | game_state: %{state.game_state | stats: stats}}

        state =
          apply_effects(
            registration.primary_effects,
            state,
            registration,
            key,
            :primary
          )

        state =
          apply_effects(
            registration.secondary_effects,
            state,
            registration,
            key,
            :secondary
          )

        state = recalculate_and_sync_skills(state, granted_skills)

        Process.send_after(
          self(),
          {:equip_autobonus_expire, key, generation},
          registration.duration_ms
        )

        {:noreply, state}

      :error ->
        {:noreply, state}
    end
  end

  @spec expire(SessionState.t(), Stats.autobonus_key(), pos_integer()) ::
          {:noreply, SessionState.t()}
  def expire(%{game_state: %{stats: stats}} = state, key, generation) do
    with {:ok, _registration} <- Map.fetch(stats.equip_autobonuses, key),
         ^generation <- Map.get(stats.active_autobonuses, key) do
      granted_skills = Stats.granted_skills(stats)
      stats = %{stats | active_autobonuses: Map.delete(stats.active_autobonuses, key)}
      state = %{state | game_state: %{state.game_state | stats: stats}}
      {:noreply, recalculate_and_sync_skills(state, granted_skills)}
    else
      _stale_or_missing -> {:noreply, state}
    end
  end

  @spec reconcile_statuses(SessionState.t()) :: {:noreply, SessionState.t()}
  def reconcile_statuses(%{game_state: game_state} = state) do
    character_id = game_state.character_id
    desired = game_state.stats.equip_statuses
    applied = state.applied_equip_statuses

    removed = Map.keys(applied) -- Map.keys(desired)
    changed = Enum.reject(desired, fn {status, params} -> applied[status] == params end)

    Enum.each(removed, &remove_equip_status(&1, character_id))

    Enum.each(changed, fn {status, {duration, value}} ->
      if Map.has_key?(applied, status), do: remove_equip_status(status, character_id)
      apply_equip_status(status, duration, value, character_id)
    end)

    state = %{state | applied_equip_statuses: desired}

    if removed == [] and changed == [] do
      {:noreply, state}
    else
      {:noreply, StatusManager.recalculate_after_status_change(state)}
    end
  end

  defp remove_equip_status(status, character_id) do
    Interpreter.remove_status(:player, character_id, status, owner_refresh: :defer)
  end

  defp apply_equip_status(status, duration, value, character_id) do
    params =
      [caster_id: character_id, val1: value, owner_refresh: :defer]
      |> maybe_put_duration(duration)

    case Interpreter.apply_status(:player, character_id, status, params) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Equipment status #{status} rejected for player #{character_id}: #{inspect(reason)}"
        )
    end
  end

  defp apply_effects(effects, state, registration, key, phase) do
    Enum.reduce(effects, state, fn
      {:status_start, status, duration, value}, state ->
        character_id = state.game_state.character_id

        params =
          [caster_id: character_id, val1: value, owner_refresh: :defer]
          |> maybe_put_duration(duration)

        case Interpreter.apply_status(:player, character_id, status, params) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "Equipment autobonus status #{status} rejected for item #{registration.item_id}, " <>
                "#{phase} proc key #{inspect(key)}: #{inspect(reason)}"
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

  defp maybe_put_duration(params, :infinite), do: params
  defp maybe_put_duration(params, duration), do: Keyword.put(params, :duration, duration)

  defp recalculate_and_sync_skills(state, previous_granted_skills) do
    state = StatusManager.recalculate_after_status_change(state)

    if Stats.granted_skills(state.game_state.stats) != previous_granted_skills do
      MessageRouter.send_to(state.connection_pid, SkillListView.build(state.game_state))
    end

    state
  end
end
