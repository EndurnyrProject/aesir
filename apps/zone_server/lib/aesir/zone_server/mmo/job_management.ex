defmodule Aesir.ZoneServer.Mmo.JobManagement do
  @moduledoc """
  Public API for job-related operations.
  Provides business logic for stat calculations and job information access.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.Jobs

  @doc """
  Get a job by its ID.
  Returns {:ok, job} or {:error, reason}
  """
  @spec get_job_by_id(integer()) :: {:ok, Job.t()} | {:error, atom()}
  def get_job_by_id(job_id) when is_integer(job_id) do
    case Jobs.by_id(job_id) do
      {:ok, job} -> {:ok, job}
      :error -> {:error, :job_not_found}
    end
  end

  @doc """
  Get a job by its name.
  Returns {:ok, job} or {:error, reason}
  """
  @spec get_job_by_name(atom()) :: {:ok, Job.t()} | {:error, atom()}
  def get_job_by_name(job_name) when is_atom(job_name) do
    case Jobs.by_name(job_name) do
      {:ok, job} -> {:ok, job}
      :error -> {:error, :job_not_found}
    end
  end

  @doc """
  Get all available jobs.
  Returns a list of Job structs.
  """
  @spec get_all_jobs() :: [Job.t()]
  def get_all_jobs do
    Jobs.all()
  end

  @doc """
  Get base HP for a job at a specific level.
  Returns {:ok, hp_value} or {:error, reason}
  """
  @spec get_base_hp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_hp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name), do: fetch_level(job.base_hp, level)
  end

  @doc """
  Get base SP for a job at a specific level.
  Returns {:ok, sp_value} or {:error, reason}
  """
  @spec get_base_sp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_sp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name), do: fetch_level(job.base_sp, level)
  end

  @doc """
  Get base AP for a job at a specific level.
  Returns {:ok, ap_value} or {:error, reason}
  """
  @spec get_base_ap(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_ap(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name), do: fetch_level(job.base_ap, level)
  end

  @doc """
  Get job exp required for a specific level.
  Returns {:ok, exp_value} or {:error, reason}
  """
  @spec get_job_exp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_job_exp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name), do: fetch_level(job.job_exp, level)
  end

  @doc """
  Get base exp required for a specific level.
  Returns {:ok, exp_value} or {:error, reason}
  """
  @spec get_base_exp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_exp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name), do: fetch_level(job.base_exp, level)
  end

  @doc """
  Get bonus stats for a job at a specific level.
  Returns {:ok, stats} or {:error, reason}
  """
  @spec get_bonus_stats(atom(), integer()) :: {:ok, Job.BonusStats.t()} | {:error, atom()}
  def get_bonus_stats(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name), do: fetch_level(job.bonus_stats, level)
  end

  @doc """
  Get base ASPD for a specific weapon type.
  Returns {:ok, aspd_value} or {:error, reason}
  """
  @spec get_base_aspd(atom(), atom()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_aspd(job_name, weapon_type) when is_atom(job_name) and is_atom(weapon_type) do
    with {:ok, job} <- get_job_by_name(job_name),
         %Job.BaseAspd{} = base_aspd <- job.base_aspd,
         aspd when not is_nil(aspd) <- Map.get(base_aspd, weapon_type) do
      {:ok, aspd}
    else
      nil -> {:error, :weapon_type_not_found}
      error -> error
    end
  end

  @doc """
  Get all base stats for a job at a specific level.
  Returns a map with hp, sp, ap, and bonus_stats.
  """
  @spec get_base_stats_for_level(atom(), integer()) :: {:ok, map()} | {:error, atom()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def get_base_stats_for_level(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name) do
      hp =
        case fetch_level(job.base_hp, level) do
          {:ok, v} -> v
          _ -> 0
        end

      sp =
        case fetch_level(job.base_sp, level) do
          {:ok, v} -> v
          _ -> 0
        end

      ap =
        case fetch_level(job.base_ap, level) do
          {:ok, v} -> v
          _ -> 0
        end

      bonus_stats =
        case fetch_level(job.bonus_stats, level) do
          {:ok, stats} -> stats
          _ -> nil
        end

      {:ok,
       %{
         hp: hp,
         sp: sp,
         ap: ap,
         bonus_stats: bonus_stats,
         max_weight: job.max_weight
       }}
    end
  end

  @doc """
  Check if a level is valid for a specific job.
  """
  @spec is_valid_base_level?(atom(), integer()) :: boolean()
  def is_valid_base_level?(job_name, level) when is_atom(job_name) and is_integer(level) do
    case get_job_by_name(job_name) do
      {:ok, job} -> level > 0 and level <= job.max_base_level
      _ -> false
    end
  end

  @spec is_valid_job_level?(atom(), integer()) :: boolean()
  def is_valid_job_level?(job_name, level) when is_atom(job_name) and is_integer(level) do
    case get_job_by_name(job_name) do
      {:ok, job} -> level > 0 and level <= job.max_job_level
      _ -> false
    end
  end

  @doc """
  Calculate total exp needed to reach a specific base level.
  """
  @spec total_base_exp_to_level(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def total_base_exp_to_level(job_name, target_level)
      when is_atom(job_name) and is_integer(target_level) do
    with {:ok, job} <- get_job_by_name(job_name),
         true <- target_level > 0 || {:error, :invalid_level} do
      total =
        job.base_exp
        |> Enum.filter(fn {level, _exp} -> level < target_level end)
        |> Enum.reduce(0, fn {_level, exp}, acc -> acc + exp end)

      {:ok, total}
    end
  end

  @doc """
  Calculate total exp needed to reach a specific job level.
  """
  @spec total_job_exp_to_level(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def total_job_exp_to_level(job_name, target_level)
      when is_atom(job_name) and is_integer(target_level) do
    with {:ok, job} <- get_job_by_name(job_name),
         true <- target_level > 0 || {:error, :invalid_level} do
      total =
        job.job_exp
        |> Enum.filter(fn {level, _exp} -> level < target_level end)
        |> Enum.reduce(0, fn {_level, exp}, acc -> acc + exp end)

      {:ok, total}
    end
  end

  defp fetch_level(table, _level) when map_size(table) == 0, do: {:error, :no_stats_defined}

  defp fetch_level(table, level) do
    case Map.fetch(table, level) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :level_out_of_range}
    end
  end
end
