defmodule Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler do
  @moduledoc """
  Awards combat experience and resolves the resulting level-ups for a player
  session.

  Experience is applied through the pure `Leveling` module. When base levels are
  gained the character is healed to full (matching rAthena's `pc_baselevelup`);
  job levels grant skill points. Recalculated stats, experience bars and skill
  points are pushed to the client and persisted.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Applies gained base/job experience to the session, leveling up as needed.
  """
  @spec handle_gain_exp(non_neg_integer(), non_neg_integer(), map()) :: {:noreply, map()}
  def handle_gain_exp(base_amount, job_amount, %{game_state: game_state} = state) do
    char_id = game_state.character_id
    old_base_level = game_state.stats.progression.base_level

    {progression, base_gained, job_gained} =
      Leveling.apply_exp(game_state.stats.progression, base_amount, job_amount)

    status_gained = StatPoint.gain(old_base_level, progression.base_level)

    progression = %{
      progression
      | skill_point: progression.skill_point + job_gained,
        status_point: progression.status_point + status_gained
    }

    stats =
      %{game_state.stats | progression: progression}
      |> Stats.calculate_stats(char_id)
      |> maybe_full_heal(base_gained)

    game_state = %{game_state | stats: stats}
    new_state = %{state | game_state: game_state}

    sync_client(new_state, progression)
    persist(char_id, stats)
    UnitRegistry.update_unit_state(:player, char_id, game_state)

    {:noreply, new_state}
  end

  defp maybe_full_heal(stats, 0), do: stats

  defp maybe_full_heal(stats, _base_gained) do
    current = %{
      stats.current_state
      | hp: stats.derived_stats.max_hp,
        sp: stats.derived_stats.max_sp
    }

    %{stats | current_state: current}
  end

  defp sync_client(state, progression) do
    StatusSync.send_stat_updates(state.connection_pid, state.game_state.stats)

    StatusSync.send_params(state.connection_pid, %{
      StatusParams.next_base_exp() => Leveling.next_base_exp(progression),
      StatusParams.next_job_exp() => Leveling.next_job_exp(progression),
      StatusParams.skill_point() => progression.skill_point,
      StatusParams.status_point() => progression.status_point
    })
  end

  defp persist(char_id, stats) do
    CharacterPersistence.update_character(
      char_id,
      %{
        base_level: stats.progression.base_level,
        job_level: stats.progression.job_level,
        base_exp: stats.progression.base_exp,
        job_exp: stats.progression.job_exp,
        hp: stats.current_state.hp,
        sp: stats.current_state.sp,
        max_hp: stats.derived_stats.max_hp,
        max_sp: stats.derived_stats.max_sp,
        skill_point: stats.progression.skill_point,
        status_point: stats.progression.status_point
      },
      async: true
    )
  end
end
