defmodule Aesir.ZoneServer.Unit.Player.Handlers.StatAllocationHandler do
  @moduledoc """
  Handles CZ_STATUS_CHANGE: spends status points to raise a primary stat.

  Validates the request against available points and the per-class parameter
  cap, applies the renewal cost, recalculates stats, persists, and syncs the
  client (ack, status-point balance, per-stat cost indicator, recalculated
  stats). Failures ack with `ok = 0` and leave state unchanged.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Packets.ZcStatusChange
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # status_id => {base-stat key, per-stat cost-indicator StatusParam id}
  @stats %{
    StatusParams.str() => {:str, StatusParams.ustr()},
    StatusParams.agi() => {:agi, StatusParams.uagi()},
    StatusParams.vit() => {:vit, StatusParams.uvit()},
    StatusParams.int() => {:int, StatusParams.uint()},
    StatusParams.dex() => {:dex, StatusParams.udex()},
    StatusParams.luk() => {:luk, StatusParams.uluk()}
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
        reject(status_id, 0, state)
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

    new_game_state = %{game_state | stats: stats}
    new_state = %{state | game_state: new_game_state}

    UnitRegistry.update_unit_state(:player, char_id, new_game_state)
    persist(char_id, stat, new_value, stats)
    sync(state.connection_pid, status_id, u_param, new_value, stats)

    {:noreply, new_state}
  end

  defp reject(status_id, value, %{connection_pid: connection_pid} = state) do
    send(
      connection_pid,
      {:send_packet, %ZcStatusChange{sp: status_id, ok: 0, value: min(value, 255)}}
    )

    {:noreply, state}
  end

  defp sync(connection_pid, status_id, u_param, new_value, stats) do
    send(
      connection_pid,
      {:send_packet, %ZcStatusChange{sp: status_id, ok: 1, value: min(new_value, 255)}}
    )

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
        max_hp: stats.derived_stats.max_hp,
        max_sp: stats.derived_stats.max_sp
      },
      async: true
    )
  end
end
