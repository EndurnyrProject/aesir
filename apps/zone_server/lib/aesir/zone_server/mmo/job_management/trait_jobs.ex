defmodule Aesir.ZoneServer.Mmo.JobManagement.TraitJobs do
  @moduledoc """
  Identifies renewal 4th (trait) jobs and gates the 3rd->4th job change.

  Single source of truth for `trait_job?/1` (consumed by `StatPoint`,
  allocation, AP computation, and progression) and for the 3rd->4th
  eligibility matrix. Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @trait_job_ids MapSet.new(
                   Enum.to_list(4252..4264) ++
                     Enum.to_list(4278..4281) ++
                     Enum.to_list(4302..4308) ++
                     [4316]
                 )

  @eligibility %{
    4252 => [4054, 4060],
    4253 => [4058, 4064],
    4254 => [4059, 4065],
    4255 => [4055, 4061],
    4256 => [4057, 4063],
    4257 => [4056, 4062],
    4258 => [4066, 4073],
    4259 => [4071, 4078],
    4260 => [4072, 4079],
    4261 => [4067, 4074],
    4262 => [4070, 4077],
    4263 => [4068, 4075],
    4264 => [4069, 4076],
    4302 => [4239],
    4303 => [4240],
    4304 => [4211],
    4305 => [4212],
    4306 => [4215],
    4307 => [4190],
    4308 => [4218]
  }

  @min_base_level 200

  @doc """
  Whether `job_id` is one of the 25 renewal 4th-job ids (including the
  alt-sprite/mounted variants, which are trait jobs but not change targets).
  """
  @spec trait_job?(non_neg_integer()) :: boolean()
  def trait_job?(job_id), do: MapSet.member?(@trait_job_ids, job_id)

  @doc """
  Whether `progression` is allowed to change into `target_job_id`.

  Non-trait targets are always allowed (existing behavior preserved). A change
  target in the eligibility matrix requires the current job to be a listed
  parent, base level 200+, and job level at or above the parent's
  `max_job_level` (read from job data, not hardcoded). Trait ids that are not
  eligibility keys (the alt-sprite/mounted variants 4278-4281, 4316) are trait
  jobs but never valid change targets, so they are always rejected.
  """
  @spec change_allowed?(PlayerProgression.t(), non_neg_integer()) ::
          :ok | {:error, :requirements_not_met}
  def change_allowed?(%PlayerProgression{} = progression, target_job_id) do
    cond do
      not trait_job?(target_job_id) ->
        :ok

      Map.has_key?(@eligibility, target_job_id) ->
        check_eligibility(progression, Map.fetch!(@eligibility, target_job_id))

      true ->
        {:error, :requirements_not_met}
    end
  end

  @spec check_eligibility(PlayerProgression.t(), [non_neg_integer()]) ::
          :ok | {:error, :requirements_not_met}
  defp check_eligibility(progression, parent_ids) do
    with true <- progression.job_id in parent_ids,
         true <- progression.base_level >= @min_base_level,
         {:ok, parent_job} <- JobManagement.get_job_by_id(progression.job_id),
         true <- progression.job_level >= parent_job.max_job_level do
      :ok
    else
      _ -> {:error, :requirements_not_met}
    end
  end
end
