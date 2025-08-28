defmodule Aesir.ZoneServer.Mmo.JobManagement.JobDataLoader do
  @moduledoc """
  GenServer responsible for loading and managing job data from configuration files.
  Provides efficient access to job information through ETS tables.
  """
  use GenServer

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.Job

  require Logger

  @doc """
  Starts the JobDataLoader GenServer.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec get_job(integer() | atom()) :: {:ok, Job.t()} | {:error, :job_not_found}
  def get_job(job_id) when is_integer(job_id) do
    lookup_job_by_id(job_id)
  end

  def get_job(job_name) when is_atom(job_name) do
    lookup_job_by_name(job_name)
  end

  @doc """
  Gets all available jobs.
  """
  @spec get_all_jobs() :: [Job.t()]
  def get_all_jobs do
    fetch_all_jobs()
  end

  @doc """
  Reloads job data from configuration files.
  For development use only.
  """
  @spec reload() :: :ok
  def reload do
    GenServer.cast(__MODULE__, :reload)
  end

  @impl true
  def init(_opts) do
    case load_job_data() do
      :ok ->
        {:ok, %{loaded: true}}

      {:error, reason} ->
        Logger.error("Failed to load job data: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast(:reload, state) do
    :ets.delete_all_objects(:job_data_by_id)
    :ets.delete_all_objects(:job_data_by_name)

    case load_job_data() do
      :ok ->
        Logger.info("Job data reloaded successfully")
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to reload job data: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp load_job_data do
    job_data_path = Application.app_dir(:zone_server, "priv/db/job.exs")

    try do
      {raw_data, _} = Code.eval_file(job_data_path)

      case transform_raw_data(raw_data) do
        {:ok, jobs} ->
          store_jobs(jobs)
          Logger.info("Loaded #{length(jobs)} jobs successfully")
          :ok

        {:error, reasons} ->
          formatted_errors = Enum.join(reasons, "\n  - ")
          {:error, "Failed to load job data. Errors:\n  - #{formatted_errors}"}
      end
    rescue
      e ->
        {:error, "Failed to load job data file: #{Exception.message(e)}"}
    end
  end

  defp transform_raw_data(raw_data) do
    {jobs, errors} =
      Enum.reduce(raw_data, {[], []}, fn job_map, {jobs, errors} ->
        case build_and_validate_job_struct(job_map) do
          {:ok, job} -> {[job | jobs], errors}
          {:error, reason} -> {jobs, [reason | errors]}
        end
      end)

    if Enum.empty?(errors) do
      {:ok, Enum.reverse(jobs)}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp build_and_validate_job_struct(job_map) do
    job_name = Map.get(job_map, :job)

    with {:ok, job_id} <- AvailableJobs.job_name_to_id(job_name) do
      base_aspd = parse_base_aspd(Map.get(job_map, :base_aspd))
      base_hp = parse_level_stats(Map.get(job_map, :base_hp, []), :hp)
      base_sp = parse_level_stats(Map.get(job_map, :base_sp, []), :sp)
      base_ap = parse_level_stats(Map.get(job_map, :base_ap, []), :ap)
      base_exp = parse_experience_stats(Map.get(job_map, :base_exp, []))
      job_exp = parse_experience_stats(Map.get(job_map, :job_exp, []))
      bonus_stats = parse_bonus_stats(Map.get(job_map, :bonus_stats, []))
      max_weight = Map.get(job_map, :max_weight, 0)

      max_base_level = determine_max_level(base_exp)
      max_job_level = determine_max_level(job_exp)

      job = %Job{
        id: job_id,
        name: job_name,
        base_aspd: base_aspd,
        base_hp: base_hp,
        base_sp: base_sp,
        base_ap: base_ap,
        base_exp: base_exp,
        job_exp: job_exp,
        bonus_stats: bonus_stats,
        max_weight: max_weight || 0,
        max_base_level: max_base_level,
        max_job_level: max_job_level,
        max_stats: nil
      }

      {:ok, job}
    end
  end

  defp parse_base_aspd(nil), do: nil

  defp parse_base_aspd(aspd_map) when is_map(aspd_map) do
    %Job.BaseAspd{
      fist: Map.get(aspd_map, :fist),
      dagger: Map.get(aspd_map, :dagger),
      one_handed_sword: Map.get(aspd_map, :"1hsword"),
      two_handed_sword: Map.get(aspd_map, :"2hsword"),
      one_handed_spear: Map.get(aspd_map, :"1hspear"),
      two_handed_spear: Map.get(aspd_map, :"2hspear"),
      one_handed_axe: Map.get(aspd_map, :"1haxe"),
      two_handed_axe: Map.get(aspd_map, :"2haxe"),
      mace: Map.get(aspd_map, :mace),
      two_handed_mace: Map.get(aspd_map, :"2hmace"),
      staff: Map.get(aspd_map, :staff),
      bow: Map.get(aspd_map, :bow),
      knuckle: Map.get(aspd_map, :knuckle),
      musical: Map.get(aspd_map, :musical),
      whip: Map.get(aspd_map, :whip),
      book: Map.get(aspd_map, :book),
      katar: Map.get(aspd_map, :katar),
      revolver: Map.get(aspd_map, :revolver),
      rifle: Map.get(aspd_map, :rifle),
      gatling: Map.get(aspd_map, :gatling),
      shotgun: Map.get(aspd_map, :shotgun),
      grenade: Map.get(aspd_map, :grenade),
      huuma: Map.get(aspd_map, :huuma),
      two_handed_staff: Map.get(aspd_map, :"2hstaff"),
      shield: Map.get(aspd_map, :shield)
    }
  end

  defp parse_base_aspd(_), do: nil

  defp parse_level_stats(nil, _field_name), do: []
  defp parse_level_stats([], _field_name), do: []

  defp parse_level_stats(stats, field_name) when is_list(stats) do
    stats
    |> Enum.map(fn
      %{level: level} = map when is_integer(level) ->
        value = Map.get(map, field_name, 0)

        case field_name do
          :hp -> %Job.BaseHp{level: level, hp: value}
          :sp -> %Job.BaseSp{level: level, sp: value}
          :ap -> %Job.BaseAp{level: level, ap: value}
          _ -> nil
        end

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.level)
  end

  defp parse_experience_stats(nil), do: []
  defp parse_experience_stats([]), do: []

  defp parse_experience_stats(stats) when is_list(stats) do
    stats
    |> Enum.map(fn
      %{level: level, exp: exp} when is_integer(level) and is_integer(exp) ->
        %Job.Experience{level: level, exp: exp}

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.level)
  end

  defp parse_bonus_stats(nil), do: []
  defp parse_bonus_stats([]), do: []

  defp parse_bonus_stats(stats) when is_list(stats) do
    stats
    |> Enum.map(fn
      %{level: level} = map when is_integer(level) ->
        %Job.BonusStats{
          level: level,
          str: Map.get(map, :str, 0),
          agi: Map.get(map, :agi, 0),
          vit: Map.get(map, :vit, 0),
          int: Map.get(map, :int, 0),
          dex: Map.get(map, :dex, 0),
          luk: Map.get(map, :luk, 0),
          pow: Map.get(map, :pow, 0),
          sta: Map.get(map, :sta, 0),
          wis: Map.get(map, :wis, 0),
          spl: Map.get(map, :spl, 0),
          con: Map.get(map, :con, 0),
          crt: Map.get(map, :crt, 0)
        }

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.level)
  end

  defp determine_max_level([]), do: 99

  defp determine_max_level(exp_table) when is_list(exp_table) do
    case List.last(exp_table) do
      %{level: level} -> level
      _ -> 99
    end
  end

  defp store_jobs(jobs) do
    Enum.each(jobs, fn job = %Job{id: id, name: name} ->
      :ets.insert(table_for(:job_data_by_id), {id, job})
      :ets.insert(table_for(:job_data_by_name), {name, job})
    end)
  end

  defp lookup_job_by_id(job_id) do
    case :ets.lookup(table_for(:job_data_by_id), job_id) do
      [{^job_id, job}] -> {:ok, job}
      [] -> {:error, :job_not_found}
    end
  end

  defp lookup_job_by_name(job_name) do
    case :ets.lookup(table_for(:job_data_by_name), job_name) do
      [{^job_name, job}] -> {:ok, job}
      [] -> {:error, :job_not_found}
    end
  end

  defp fetch_all_jobs do
    :ets.tab2list(table_for(:job_data_by_name))
    |> Enum.map(fn {_name, job} -> job end)
  end
end
