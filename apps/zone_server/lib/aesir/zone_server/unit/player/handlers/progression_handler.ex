defmodule Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler do
  @moduledoc """
  Applies GM-driven progression changes to a player session: adding base levels,
  adding job levels, and changing the character's job.

  These mirror rAthena's `@baselvlup`/`@joblvlup`/`@job` commands. Level gains
  clamp to the job's caps, grant the matching status/skill points, and (for base
  levels) full-heal the character, matching `pc_baselevelup`. A job change updates
  the class sprite for the player and nearby observers and recomputes
  job-dependent stats.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.LookType
  alias Aesir.ZoneServer.Unit.Player.SkillListView
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Adds `amount` base levels, clamped to the job's `max_base_level`. Grants the
  status points earned across the gained levels and full-heals the character.
  """
  @spec handle_add_base_level(pos_integer(), map()) :: {:noreply, map()}
  def handle_add_base_level(amount, %{game_state: game_state} = state) do
    progression = game_state.stats.progression
    {:ok, job} = job_for(progression)
    old_level = progression.base_level
    new_level = min(old_level + amount, job.max_base_level)
    status_gained = StatPoint.gain(old_level, new_level)

    progression = %{
      progression
      | base_level: new_level,
        base_exp: 0,
        status_point: progression.status_point + status_gained
    }

    stats =
      %{game_state.stats | progression: progression}
      |> Stats.calculate_stats(game_state.character_id)
      |> full_heal()

    commit(state, %{game_state | stats: stats}, progression)
  end

  @doc """
  Adds `amount` job levels, clamped to the job's `max_job_level`. Grants one skill
  point per gained level.
  """
  @spec handle_add_job_level(pos_integer(), map()) :: {:noreply, map()}
  def handle_add_job_level(amount, %{game_state: game_state} = state) do
    progression = game_state.stats.progression
    {:ok, job} = job_for(progression)
    old_level = progression.job_level
    new_level = min(old_level + amount, job.max_job_level)

    progression = %{
      progression
      | job_level: new_level,
        job_exp: 0,
        skill_point: progression.skill_point + (new_level - old_level)
    }

    stats =
      Stats.calculate_stats(
        %{game_state.stats | progression: progression},
        game_state.character_id
      )

    commit(state, %{game_state | stats: stats}, progression)
  end

  @doc """
  Changes the character's job to `job_id`, recomputes job-dependent stats,
  full-heals, and broadcasts the new class sprite to the player and nearby
  observers.

  Thin wrapper over `apply_job_change/2` kept as the `{:noreply, _}` entry
  point for `PlayerSession`'s `{:change_job, _}` info handler (driven by
  `JobChange.request/2`); an unknown `job_id` leaves `state` untouched.
  """
  @spec handle_change_job(non_neg_integer(), map()) :: {:noreply, map()}
  def handle_change_job(job_id, state) do
    case apply_job_change(job_id, state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @doc """
  Authoritative core for a job change: validates `job_id`, updates
  `progression.job_id`, recomputes job-dependent stats, full-heals, notifies
  the client (class sprite, refreshed skill list, stat/param sync), persists
  `class:`, and updates the `UnitRegistry`.

  Returns `{:error, :unknown_job}` without mutating `state` when `job_id`
  does not resolve to a known job.
  """
  @spec apply_job_change(non_neg_integer(), map()) :: {:ok, map()} | {:error, :unknown_job}
  def apply_job_change(job_id, %{game_state: game_state} = state) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, _job_name} -> do_apply_job_change(job_id, state, game_state)
      {:error, :unknown_job_id} -> {:error, :unknown_job}
    end
  end

  defp do_apply_job_change(job_id, state, game_state) do
    progression = %{game_state.stats.progression | job_id: job_id}

    stats =
      %{game_state.stats | progression: progression}
      |> Stats.calculate_stats(game_state.character_id)
      |> full_heal()

    game_state = %{game_state | stats: stats}

    sprite = %SpriteChange{
      gid: game_state.character_id,
      type: LookType.base(),
      val: job_id,
      val2: 0
    }

    StatusSync.send_param(state.connection_pid, StatusParams.job_level(), progression.job_level)
    Broadcast.to_player(game_state.character_id, sprite)
    Broadcast.to_visible_players(game_state, sprite, exclude_id: game_state.character_id)

    skill_list = SkillListView.build(progression)
    MessageRouter.send_to(state.connection_pid, skill_list)

    {:noreply, new_state} = commit(state, game_state, progression, class: job_id)
    {:ok, new_state}
  end

  defp commit(state, game_state, progression, extra_persist \\ []) do
    new_state = %{state | game_state: game_state}

    sync_client(new_state, progression)
    persist(game_state, extra_persist)
    UnitRegistry.update_unit_state(:player, game_state.character_id, game_state)

    {:noreply, new_state}
  end

  defp full_heal(stats) do
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

  defp persist(game_state, extra) do
    stats = game_state.stats

    fields =
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
      }
      |> Map.merge(Map.new(extra))

    CharacterPersistence.update_character(game_state.character_id, fields, async: true)
  end

  defp job_for(progression) do
    with {:ok, name} <- AvailableJobs.job_id_to_name(progression.job_id) do
      JobManagement.get_job_by_name(name)
    end
  end
end
