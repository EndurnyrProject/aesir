defmodule Aesir.ZoneServer.Mmo.Leveling do
  @moduledoc """
  Pure experience and level-up resolution.

  Given a player's progression and an amount of base/job experience gained,
  resolves any base and job levels gained, handling multi-level overflow and
  the per-job level caps. All thresholds come from `JobManagement`, where the
  value stored at level `L` is the experience required to advance from `L` to
  `L + 1`. At max level experience keeps accumulating up to the max-level exp
  limit (`99_999_999` base, `999_999_999` job), which is also the next-level
  exp reported there.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression, as: Progression

  @max_level_base_exp 99_999_999
  @max_level_job_exp 999_999_999

  @doc """
  Applies gained base/job experience to a progression.

  Returns the updated progression along with the number of base levels and job
  levels gained, so callers can react to level-ups (heal, grant points, etc.).
  """
  @spec apply_exp(Progression.t(), non_neg_integer(), non_neg_integer()) ::
          {Progression.t(), non_neg_integer(), non_neg_integer()}
  def apply_exp(%Progression{} = progression, gained_base, gained_job)
      when gained_base >= 0 and gained_job >= 0 do
    job_name = job_name!(progression)
    {max_base, max_job} = max_levels(job_name)

    base_track = {:base_level, :base_exp, max_base, @max_level_base_exp}
    job_track = {:job_level, :job_exp, max_job, @max_level_job_exp}

    {progression, base_gained} =
      progression
      |> gain(base_track, gained_base)
      |> level_up(base_track, &JobManagement.get_base_exp(job_name, &1))

    {progression, job_gained} =
      progression
      |> gain(job_track, gained_job)
      |> level_up(job_track, &JobManagement.get_job_exp(job_name, &1))

    {progression, base_gained, job_gained}
  end

  @doc """
  Experience required to reach the next base level, or the max-level base exp
  limit when already at max base level.
  """
  @spec next_base_exp(Progression.t()) :: non_neg_integer()
  def next_base_exp(%Progression{base_level: level} = progression) do
    job_name = job_name!(progression)
    {max_base, _} = max_levels(job_name)
    next_exp(level, max_base, @max_level_base_exp, JobManagement.get_base_exp(job_name, level))
  end

  @doc """
  Experience required to reach the next job level, or the max-level job exp
  limit when already at max job level.
  """
  @spec next_job_exp(Progression.t()) :: non_neg_integer()
  def next_job_exp(%Progression{job_level: level} = progression) do
    job_name = job_name!(progression)
    {_, max_job} = max_levels(job_name)
    next_exp(level, max_job, @max_level_job_exp, JobManagement.get_job_exp(job_name, level))
  end

  @doc """
  Base/job experience to subtract on death with `death_penalty_type` 1, rates
  in 1/10000 (100 = 1%) of the exp needed for the next level. See
  `death_penalty/5`.
  """
  @spec death_penalty(Progression.t(), non_neg_integer(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer()}
  def death_penalty(%Progression{} = progression, base_rate, job_rate),
    do: death_penalty(progression, 1, base_rate, job_rate, Config.death_penalty_maxlv())

  @doc """
  Base/job experience to subtract on death. Type 1 takes `rate / 10000` of the
  exp needed for the next level, type 2 of the exp into the current level,
  truncated. A track at its max level loses nothing unless `maxlv` allows it
  (bit 1 base, bit 2 job); there the next-level exp is the max-level exp limit.
  Each loss is capped at the exp into the level, so it never de-levels.
  """
  @spec death_penalty(Progression.t(), 1 | 2, non_neg_integer(), non_neg_integer(), 0..3) ::
          {non_neg_integer(), non_neg_integer()}
  def death_penalty(%Progression{} = progression, type, base_rate, job_rate, maxlv)
      when type in [1, 2] and base_rate >= 0 and job_rate >= 0 do
    job_name = job_name!(progression)
    {max_base, max_job} = max_levels(job_name)
    base_max? = progression.base_level >= max_base
    job_max? = progression.job_level >= max_job

    {track_loss(
       type,
       progression.base_exp,
       next_base_exp(progression),
       base_rate,
       base_max?,
       Bitwise.band(maxlv, 1) != 0
     ),
     track_loss(
       type,
       progression.job_exp,
       next_job_exp(progression),
       job_rate,
       job_max?,
       Bitwise.band(maxlv, 2) != 0
     )}
  end

  defp track_loss(_type, _exp, _next, rate, _max?, _maxlv?) when rate <= 0, do: 0
  defp track_loss(_type, _exp, _next, _rate, true, false), do: 0
  defp track_loss(1, exp, next, rate, _max?, _maxlv?), do: min(exp, trunc(next * (rate / 10_000)))
  defp track_loss(2, exp, _next, rate, _max?, _maxlv?), do: min(exp, trunc(exp * (rate / 10_000)))

  defp gain(progression, {level_key, exp_key, max_level, exp_limit}, amount) do
    exp = Map.fetch!(progression, exp_key)

    if Map.fetch!(progression, level_key) >= max_level,
      do: Map.put(progression, exp_key, max(exp, min(exp + amount, exp_limit))),
      else: Map.put(progression, exp_key, exp + amount)
  end

  defp level_up(progression, track, threshold_fun),
    do: do_level_up(progression, track, threshold_fun, 0)

  defp do_level_up(progression, {level_key, exp_key, max_level, exp_limit} = track, fun, gained) do
    level = Map.fetch!(progression, level_key)
    exp = Map.fetch!(progression, exp_key)

    cond do
      level >= max_level and gained == 0 ->
        {progression, 0}

      level >= max_level ->
        {Map.put(progression, exp_key, min(exp, exp_limit)), gained}

      true ->
        case fun.(level) do
          {:ok, req} when exp >= req ->
            progression
            |> Map.put(level_key, level + 1)
            |> Map.put(exp_key, exp - req)
            |> do_level_up(track, fun, gained + 1)

          _ ->
            {progression, gained}
        end
    end
  end

  # Each job's own max level table is the primary ceiling; the server-wide caps
  # (`Config.max_base_level/0`, `Config.max_job_level/0`) can only lower it.
  defp max_levels(job_name) do
    {:ok, job} = JobManagement.get_job_by_name(job_name)

    {min(job.max_base_level, Config.max_base_level()),
     min(job.max_job_level, Config.max_job_level())}
  end

  defp job_name!(%Progression{job_id: job_id}) do
    {:ok, job_name} = AvailableJobs.job_id_to_name(job_id)
    job_name
  end

  defp next_exp(level, max_level, exp_limit, _result) when level >= max_level, do: exp_limit
  defp next_exp(_level, _max_level, _exp_limit, {:ok, exp}), do: exp
  defp next_exp(_level, _max_level, _exp_limit, _result), do: 0
end
