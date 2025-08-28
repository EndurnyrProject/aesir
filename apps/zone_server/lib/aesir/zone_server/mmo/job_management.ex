defmodule Aesir.ZoneServer.Mmo.JobManagement do
  @moduledoc """
  Public API for job-related operations.
  Provides business logic for stat calculations and job information access.
  """
  require Logger

  alias Aesir.ZoneServer.Mmo.JobManagement.Job
  alias Aesir.ZoneServer.Mmo.JobManagement.JobDataLoader

  @doc """
  Get a job by its ID.
  Returns {:ok, job} or {:error, reason}
  """
  @spec get_job_by_id(integer()) :: {:ok, Job.t()} | {:error, atom()}
  def get_job_by_id(job_id) when is_integer(job_id) do
    JobDataLoader.get_job(job_id)
  end

  @doc """
  Get a job by its name.
  Returns {:ok, job} or {:error, reason}
  """
  @spec get_job_by_name(atom()) :: {:ok, Job.t()} | {:error, atom()}
  def get_job_by_name(job_name) when is_atom(job_name) do
    JobDataLoader.get_job(job_name)
  end

  @doc """
  Get all available jobs.
  Returns a list of Job structs.
  """
  @spec get_all_jobs() :: [Job.t()]
  def get_all_jobs do
    JobDataLoader.get_all_jobs()
  end

  @doc """
  Get base HP for a job at a specific level.
  Returns {:ok, hp_value} or {:error, reason}
  """
  @spec get_base_hp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_hp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name),
         {:ok, hp_struct} <- find_stat_for_level(job.base_hp, level) do
      {:ok, hp_struct.hp}
    end
  end

  @doc """
  Get base SP for a job at a specific level.
  Returns {:ok, sp_value} or {:error, reason}
  """
  @spec get_base_sp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_sp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name),
         {:ok, sp_struct} <- find_stat_for_level(job.base_sp, level) do
      {:ok, sp_struct.sp}
    end
  end

  @doc """
  Get base AP for a job at a specific level.
  Returns {:ok, ap_value} or {:error, reason}
  """
  @spec get_base_ap(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_ap(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name),
         {:ok, ap_struct} <- find_stat_for_level(job.base_ap, level) do
      {:ok, ap_struct.ap}
    end
  end

  @doc """
  Get job exp required for a specific level.
  Returns {:ok, exp_value} or {:error, reason}
  """
  @spec get_job_exp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_job_exp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name),
         {:ok, exp_struct} <- find_stat_for_level(job.job_exp, level) do
      {:ok, exp_struct.exp}
    end
  end

  @doc """
  Get base exp required for a specific level.
  Returns {:ok, exp_value} or {:error, reason}
  """
  @spec get_base_exp(atom(), integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_base_exp(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name),
         {:ok, exp_struct} <- find_stat_for_level(job.base_exp, level) do
      {:ok, exp_struct.exp}
    end
  end

  @doc """
  Get bonus stats for a job at a specific level.
  Returns {:ok, stats} or {:error, reason}
  """
  @spec get_bonus_stats(atom(), integer()) :: {:ok, Job.BonusStats.t()} | {:error, atom()}
  def get_bonus_stats(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name) do
      find_stat_for_level(job.bonus_stats, level)
    end
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
  def get_base_stats_for_level(job_name, level) when is_atom(job_name) and is_integer(level) do
    with {:ok, job} <- get_job_by_name(job_name) do
      hp =
        case find_stat_for_level(job.base_hp, level) do
          {:ok, hp_struct} -> hp_struct.hp
          _ -> 0
        end

      sp =
        case find_stat_for_level(job.base_sp, level) do
          {:ok, sp_struct} -> sp_struct.sp
          _ -> 0
        end

      ap =
        case find_stat_for_level(job.base_ap, level) do
          {:ok, ap_struct} -> ap_struct.ap
          _ -> 0
        end

      bonus_stats =
        case find_stat_for_level(job.bonus_stats, level) do
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
        |> Enum.filter(fn %{level: l} -> l < target_level end)
        |> Enum.reduce(0, fn %{exp: exp}, acc -> acc + exp end)

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
        |> Enum.filter(fn %{level: l} -> l < target_level end)
        |> Enum.reduce(0, fn %{exp: exp}, acc -> acc + exp end)

      {:ok, total}
    end
  end

  defp find_stat_for_level([], _level), do: {:error, :no_stats_defined}
  defp find_stat_for_level(nil, _level), do: {:error, :no_stats_defined}

  defp find_stat_for_level(stats, level) when is_list(stats) and is_integer(level) do
    case Enum.filter(stats, fn
           %{level: entry_level} -> entry_level <= level
           _ -> false
         end) do
      [] ->
        # If no entry found, check if we have any stats at all
        case stats do
          [] -> {:error, :no_stats_defined}
          _ -> {:error, :level_out_of_range}
        end

      filtered ->
        # Get the highest level entry that's <= target level
        result =
          filtered
          |> Enum.sort_by(& &1.level, :desc)
          |> List.first()

        {:ok, result}
    end
  end
end
