defmodule Aesir.ZoneServer.Mmo.Leveling do
  @moduledoc """
  Pure experience and level-up resolution.

  Given a player's progression and an amount of base/job experience gained,
  resolves any base and job levels gained, handling multi-level overflow and
  the per-job level caps. All thresholds come from `JobManagement`, where the
  value stored at level `L` is the experience required to advance from `L` to
  `L + 1`.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression, as: Progression

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

    {progression, base_gained} =
      progression
      |> Map.update!(:base_exp, &(&1 + gained_base))
      |> level_up(:base_level, :base_exp, &JobManagement.get_base_exp(job_name, &1), max_base)

    {progression, job_gained} =
      progression
      |> Map.update!(:job_exp, &(&1 + gained_job))
      |> level_up(:job_level, :job_exp, &JobManagement.get_job_exp(job_name, &1), max_job)

    {progression, base_gained, job_gained}
  end

  @doc """
  Experience required to reach the next base level, or 0 if already maxed.
  """
  @spec next_base_exp(Progression.t()) :: non_neg_integer()
  def next_base_exp(%Progression{base_level: level} = progression) do
    job_name = job_name!(progression)
    {max_base, _} = max_levels(job_name)
    threshold(level, max_base, JobManagement.get_base_exp(job_name, level))
  end

  @doc """
  Experience required to reach the next job level, or 0 if already maxed.
  """
  @spec next_job_exp(Progression.t()) :: non_neg_integer()
  def next_job_exp(%Progression{job_level: level} = progression) do
    job_name = job_name!(progression)
    {_, max_job} = max_levels(job_name)
    threshold(level, max_job, JobManagement.get_job_exp(job_name, level))
  end

  @doc """
  Base/job experience to subtract on death, as a percentage of the exp required
  to reach the next level.

  Each track loses `min(current_exp_into_level, next_level_exp * pct / 100)`, so
  the penalty never de-levels the character and never goes negative. At the level
  cap (`next_*_exp/1` returns 0) or on a fresh level (0 exp into it) the loss is 0.
  """
  @spec death_penalty(Progression.t(), non_neg_integer(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer()}
  def death_penalty(%Progression{} = progression, base_pct, job_pct)
      when base_pct >= 0 and job_pct >= 0 do
    base_loss = min(progression.base_exp, div(next_base_exp(progression) * base_pct, 100))
    job_loss = min(progression.job_exp, div(next_job_exp(progression) * job_pct, 100))
    {base_loss, job_loss}
  end

  defp level_up(progression, level_key, exp_key, threshold_fun, max_level) do
    do_level_up(progression, level_key, exp_key, threshold_fun, max_level, 0)
  end

  defp do_level_up(progression, level_key, exp_key, threshold_fun, max_level, gained) do
    level = Map.fetch!(progression, level_key)
    exp = Map.fetch!(progression, exp_key)

    if level >= max_level do
      {Map.put(progression, exp_key, 0), gained}
    else
      case threshold_fun.(level) do
        {:ok, req} when exp >= req ->
          progression
          |> Map.put(level_key, level + 1)
          |> Map.put(exp_key, exp - req)
          |> do_level_up(level_key, exp_key, threshold_fun, max_level, gained + 1)

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

  defp threshold(level, max_level, _result) when level >= max_level, do: 0
  defp threshold(_level, _max_level, {:ok, exp}), do: exp
  defp threshold(_level, _max_level, _result), do: 0
end
