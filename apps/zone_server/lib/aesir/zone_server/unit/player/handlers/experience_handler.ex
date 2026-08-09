defmodule Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler do
  @moduledoc """
  Awards combat experience and resolves the resulting level-ups for a player
  session.

  Experience is applied through the pure `Leveling` module. When base levels are
  gained the character is healed to full; job levels grant skill points.
  Recalculated stats, experience bars and skill points are pushed to the client
  and persisted.

  Percent EXP sources — the `:exp_rate`/`:job_exp_rate` status modifiers and
  the per-race/per-class equipment bonuses of a mob kill — stack **additively** into a single
  percentage applied once to the incoming amount, rather than as successive
  multiplications. Two 10% sources therefore grant 20%, not 21%, and the amount
  is truncated exactly once instead of once per source.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Applies gained base/job experience to the session, leveling up as needed.

  Equivalent to `handle_gain_exp/5` with no source race or class: used by
  experience that did not come from a kill (script rewards), which no equipment
  kill bonus applies to.
  """
  @spec handle_gain_exp(non_neg_integer(), non_neg_integer(), map()) :: {:noreply, map()}
  def handle_gain_exp(base_amount, job_amount, state) do
    handle_gain_exp(base_amount, job_amount, nil, nil, state)
  end

  @doc """
  Applies gained base/job experience from killing a mob of race `mob_race` and
  class `mob_class`, leveling up as needed.

  The matching and wildcard race/class equipment bonuses are added to the flat
  `:exp_rate` / `:job_exp_rate` status percentages before the single rate
  application. They boost base and job experience alike. A `nil` source axis
  grants no equipment bonus.
  """
  @spec handle_gain_exp(
          non_neg_integer(),
          non_neg_integer(),
          atom() | nil,
          atom() | nil,
          map()
        ) :: {:noreply, map()}
  def handle_gain_exp(
        base_amount,
        job_amount,
        mob_race,
        mob_class,
        %{game_state: game_state} = state
      ) do
    char_id = game_state.character_id
    old_base_level = game_state.stats.progression.base_level

    modifiers = ModifierCalculator.get_all_modifiers(:player, char_id)

    exp_rate =
      Map.get(modifiers, :exp_rate, 0) +
        exp_add_race(game_state.stats, mob_race) +
        exp_add_class(game_state.stats, mob_class)

    job_exp_rate = Map.get(modifiers, :job_exp_rate, 0)

    base_amount = boost_exp(base_amount, 100 + exp_rate)
    job_amount = boost_exp(job_amount, 100 + exp_rate + job_exp_rate)

    {progression, base_gained, job_gained} =
      Leveling.apply_exp(game_state.stats.progression, base_amount, job_amount)

    status_gained = StatPoint.gain(old_base_level, progression.base_level)
    trait_gained = StatPoint.trait_gain(old_base_level, progression.base_level)

    progression = %{
      progression
      | skill_point: progression.skill_point + job_gained,
        status_point: progression.status_point + status_gained,
        trait_point: progression.trait_point + trait_gained
    }

    stats =
      %{game_state.stats | progression: progression}
      |> Stats.calculate_stats(char_id)
      |> maybe_full_heal(base_gained)

    game_state = %{game_state | stats: stats}
    new_state = %{state | game_state: game_state}

    sync_client(new_state, progression)
    persist(char_id, stats)
    new_state = StateCommit.commit(state, game_state)

    {:noreply, new_state}
  end

  defp boost_exp(amount, _pct) when amount <= 0, do: amount
  defp boost_exp(amount, pct), do: max(1, div(amount * pct, 100))

  # Percent EXP the worn equipment grants against `mob_race`, summing the
  # race-specific entry with the wildcard one the way every other equipment
  # family reads.
  defp exp_add_race(_stats, nil), do: 0

  defp exp_add_race(stats, mob_race) do
    equipment = stats.modifiers.equipment
    race = bonus_race(mob_race)

    Map.get(equipment, {:exp_add_race, race}, 0) +
      Map.get(equipment, {:exp_add_race, :all}, 0)
  end

  # The mob data spells the player race `:player`, while the item-script race
  # vocabulary (and every other combat race read) spells it `:player_human`.
  defp bonus_race(:player), do: RaceModifiers.player_race()
  defp bonus_race(race) when is_atom(race), do: race

  defp exp_add_class(_stats, nil), do: 0

  defp exp_add_class(stats, mob_class) do
    equipment = stats.modifiers.equipment

    Map.get(equipment, {:exp_add_class, mob_class}, 0) +
      Map.get(equipment, {:exp_add_class, :all}, 0)
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
      StatusParams.status_point() => progression.status_point,
      StatusParams.trait_point() => progression.trait_point
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
        ap: stats.current_state.ap,
        max_hp: stats.derived_stats.max_hp,
        max_sp: stats.derived_stats.max_sp,
        max_ap: stats.derived_stats.max_ap,
        skill_point: stats.progression.skill_point,
        status_point: stats.progression.status_point,
        trait_point: stats.progression.trait_point
      },
      async: true
    )
  end
end
