defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler do
  @moduledoc """
  Handles CZ_STATUS_CHANGE: spends status points to raise a primary stat.

  Validates the request against available points and the per-class parameter
  cap, applies the active mode's cost, recalculates stats, persists, and syncs
  the client (ack, status-point balance, per-stat cost indicator, recalculated
  stats). Trait allocation is refused in pre-renewal. Failures ack with
  `ok = 0` and leave state unchanged.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.StatUpResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  # status_id => {base-stat key, per-stat cost-indicator StatusParam id}
  @stats %{
    StatusParams.str() => {:str, StatusParams.ustr()},
    StatusParams.agi() => {:agi, StatusParams.uagi()},
    StatusParams.vit() => {:vit, StatusParams.uvit()},
    StatusParams.int() => {:int, StatusParams.uint()},
    StatusParams.dex() => {:dex, StatusParams.udex()},
    StatusParams.luk() => {:luk, StatusParams.uluk()}
  }

  # Trait (4th-job) stats: spent from the separate trait-point pool at a flat
  # 1-point cost, capped by `max_trait_parameter` (100 on trait jobs, 0 else).
  @trait_stats %{
    StatusParams.pow() => {:pow, StatusParams.upow()},
    StatusParams.sta() => {:sta, StatusParams.usta()},
    StatusParams.wis() => {:wis, StatusParams.uwis()},
    StatusParams.spl() => {:spl, StatusParams.uspl()},
    StatusParams.con() => {:con, StatusParams.ucon()},
    StatusParams.crt() => {:crt, StatusParams.ucrt()}
  }

  @doc """
  Processes a stat-raise request for the player session.
  """
  @spec handle_status_up(integer(), integer(), map()) :: {:noreply, map()}
  def handle_status_up(status_id, amount, %{game_state: game_state} = state) do
    case Map.fetch(@stats, status_id) do
      {:ok, {stat, u_param}} ->
        apply_status_up(status_id, stat, u_param, amount, state, game_state)

      :error ->
        case Map.fetch(@trait_stats, status_id) do
          {:ok, {stat, u_param}} ->
            apply_trait_status_up(status_id, stat, u_param, amount, state, game_state)

          :error ->
            reject(status_id, 0, state)
        end
    end
  end

  defp apply_status_up(status_id, stat, u_param, amount, state, game_state) do
    stats = game_state.stats
    current = Map.fetch!(stats.base_stats, stat)
    available = stats.progression.status_point
    max_param = StatPoint.max_parameter(stats.progression.job_id)
    increase = min(amount, StatPoint.max_increase(current, available, max_param))

    if increase <= 0 do
      reject(status_id, current, state)
    else
      commit(status_id, stat, u_param, current, increase, available, state, game_state)
    end
  end

  defp commit(status_id, stat, u_param, current, increase, available, state, game_state) do
    char_id = game_state.character_id
    new_value = current + increase
    needed = StatPoint.points_needed(current, increase)

    progression = %{game_state.stats.progression | status_point: available - needed}
    base_stats = Map.put(game_state.stats.base_stats, stat, new_value)

    stats =
      %{game_state.stats | base_stats: base_stats, progression: progression}
      |> Stats.calculate_stats(char_id)
      |> clamp_resources()

    new_game_state = %{game_state | stats: stats}
    new_state = StateCommit.commit(state, new_game_state)

    persist(char_id, stat, new_value, stats)
    sync(state.connection_pid, status_id, u_param, new_value, stats)

    {:noreply, new_state}
  end

  defp apply_trait_status_up(status_id, stat, u_param, amount, state, game_state) do
    stats = game_state.stats
    current = Map.fetch!(stats.base_stats, stat)

    case GameMode.mode() do
      :pre_renewal ->
        reject(status_id, current, state)

      :renewal ->
        available = stats.progression.trait_point
        max = StatPoint.max_trait_parameter(stats.progression.job_id)
        increase = min(amount, min(max - current, available))

        if increase <= 0 do
          reject(status_id, current, state)
        else
          commit_trait(status_id, stat, u_param, current, increase, available, state, game_state)
        end
    end
  end

  defp commit_trait(status_id, stat, u_param, current, increase, available, state, game_state) do
    char_id = game_state.character_id
    new_value = current + increase
    needed = increase

    progression = %{game_state.stats.progression | trait_point: available - needed}
    base_stats = Map.put(game_state.stats.base_stats, stat, new_value)

    stats =
      %{game_state.stats | base_stats: base_stats, progression: progression}
      |> Stats.calculate_stats(char_id)
      |> clamp_resources()

    new_game_state = %{game_state | stats: stats}
    new_state = StateCommit.commit(state, new_game_state)

    persist_trait(char_id, stat, new_value, stats)
    sync_trait(state.connection_pid, status_id, u_param, new_value, stats)

    {:noreply, new_state}
  end

  defp reject(status_id, value, %{connection_pid: connection_pid} = state) do
    MessageRouter.send_to(connection_pid, %StatUpResult{
      stat_id: status_id,
      ok: false,
      value: min(value, 255)
    })

    {:noreply, state}
  end

  defp sync(connection_pid, status_id, u_param, new_value, stats) do
    MessageRouter.send_to(connection_pid, %StatUpResult{
      stat_id: status_id,
      ok: true,
      value: min(new_value, 255)
    })

    StatusSync.send_params(connection_pid, %{
      StatusParams.status_point() => stats.progression.status_point,
      u_param => StatPoint.cost_to_raise(new_value)
    })

    StatusSync.send_stat_updates(connection_pid, stats)
  end

  defp persist(char_id, stat, new_value, stats) do
    CharacterPersistence.update_character(
      char_id,
      %{
        stat => new_value,
        status_point: stats.progression.status_point,
        hp: stats.current_state.hp,
        sp: stats.current_state.sp,
        ap: stats.current_state.ap,
        max_hp: stats.derived_stats.max_hp,
        max_sp: stats.derived_stats.max_sp,
        max_ap: stats.derived_stats.max_ap
      },
      async: true
    )
  end

  defp sync_trait(connection_pid, status_id, u_param, new_value, stats) do
    MessageRouter.send_to(connection_pid, %StatUpResult{
      stat_id: status_id,
      ok: true,
      value: min(new_value, 255)
    })

    StatusSync.send_params(connection_pid, %{
      StatusParams.trait_point() => stats.progression.trait_point,
      u_param => 1
    })

    StatusSync.send_stat_updates(connection_pid, stats)
  end

  defp persist_trait(char_id, stat, new_value, stats) do
    CharacterPersistence.update_character(
      char_id,
      %{
        stat => new_value,
        trait_point: stats.progression.trait_point,
        hp: stats.current_state.hp,
        sp: stats.current_state.sp,
        ap: stats.current_state.ap,
        max_hp: stats.derived_stats.max_hp,
        max_sp: stats.derived_stats.max_sp,
        max_ap: stats.derived_stats.max_ap
      },
      async: true
    )
  end

  defp clamp_resources(stats) do
    current = %{
      stats.current_state
      | hp: min(stats.current_state.hp, stats.derived_stats.max_hp),
        sp: min(stats.current_state.sp, stats.derived_stats.max_sp),
        ap: min(stats.current_state.ap, stats.derived_stats.max_ap)
    }

    %{stats | current_state: current}
  end
end
