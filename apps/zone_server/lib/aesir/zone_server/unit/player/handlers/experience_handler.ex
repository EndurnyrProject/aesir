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
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Applies gained base/job experience to the session, leveling up as needed.
  """
  @spec handle_gain_exp(non_neg_integer(), non_neg_integer(), map()) :: {:noreply, map()}
  def handle_gain_exp(base_amount, job_amount, %{character: character} = state) do
    {progression, base_gained, job_gained} =
      Leveling.apply_exp(state.game_state.stats.progression, base_amount, job_amount)

    stats =
      %{state.game_state.stats | progression: progression}
      |> Stats.calculate_stats(character.id)
      |> maybe_full_heal(base_gained)

    skill_point = character.skill_point + job_gained

    character = %{
      character
      | base_level: progression.base_level,
        job_level: progression.job_level,
        base_exp: progression.base_exp,
        job_exp: progression.job_exp,
        hp: stats.current_state.hp,
        sp: stats.current_state.sp,
        max_hp: stats.derived_stats.max_hp,
        max_sp: stats.derived_stats.max_sp,
        skill_point: skill_point
    }

    game_state = %{state.game_state | stats: stats}
    new_state = %{state | game_state: game_state, character: character}

    sync_client(new_state, progression, skill_point)
    persist(character)
    UnitRegistry.update_unit_state(:player, character.id, game_state)

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

  defp sync_client(state, progression, skill_point) do
    StatusSync.send_stat_updates(state.connection_pid, state.game_state.stats)

    StatusSync.send_params(state.connection_pid, %{
      StatusParams.next_base_exp() => Leveling.next_base_exp(progression),
      StatusParams.next_job_exp() => Leveling.next_job_exp(progression),
      StatusParams.skill_point() => skill_point
    })
  end

  # no status-point award yet (needs the statpoint table + stat
  # allocation packet). Leveling already scales HP/SP/ATK/DEF directly.
  defp persist(character) do
    CharacterPersistence.update_character(
      character.id,
      %{
        base_level: character.base_level,
        job_level: character.job_level,
        base_exp: character.base_exp,
        job_exp: character.job_exp,
        hp: character.hp,
        sp: character.sp,
        max_hp: character.max_hp,
        max_sp: character.max_sp,
        skill_point: character.skill_point
      },
      async: true
    )
  end
end
