defmodule Aesir.ZoneServer.Mmo.StatPoint do
  @moduledoc """
  Status-point table and mode-specific cost formulas.

  The cumulative status-point table (`points_at/1`, `gain/2`) is loaded as data
  and cached in `:persistent_term`, mirroring `JobManagement.Jobs`. The spend
  cost delegates to the active mechanics implementation; the parameter caps
  follow one per-class cascade, the same in both modes.
  Plain functions only - no process.
  """

  import Bitwise

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid
  alias Aesir.ZoneServer.Mmo.JobManagement.Jobs
  alias Aesir.ZoneServer.Mmo.JobManagement.TraitJobs
  alias Aesir.ZoneServer.Mmo.Mechanics

  @pt_key __MODULE__
  @cache_file "statpoint_v2.etf"

  # Primary and trait stat caps per class.
  @max_parameter 99
  @max_trans_parameter 99
  @max_third_parameter 130
  @max_third_trans_parameter 130
  @max_baby_parameter 80
  @max_baby_third_parameter 117
  @max_extended_parameter 130
  @max_summoner_parameter 130
  @max_fourth_parameter 130
  @max_trait_parameter 110

  # Mapid branch/version bits and masks.
  @jobl_third 0x1000
  @jobl_upper 0x100000
  @jobl_baby 0x200000
  @mapid_firstmask 0xFF
  @mapid_secondmask 0xFFF
  @mapid_summoner 0xA
  @mapid_rebellion 0x108
  @mapid_kagerou_oboro 0x109

  @doc """
  Cumulative status points granted from base level 1 up to `level`, clamped to
  the table's maximum level.
  """
  @spec points_at(pos_integer()) :: non_neg_integer()
  def points_at(level) when level >= 1 do
    {points, _trait_points} = at(level)
    points
  end

  @doc """
  Cumulative trait points granted from base level 1 up to `level`, clamped to
  the table's maximum level. Tables without a trait-point column return 0.
  """
  @spec trait_points_at(pos_integer()) :: non_neg_integer()
  def trait_points_at(level) when level >= 1 do
    {_points, trait_points} = at(level)
    trait_points
  end

  @doc """
  Status points granted by leveling from `from_level` to `to_level`.
  """
  @spec gain(pos_integer(), pos_integer()) :: non_neg_integer()
  def gain(from_level, to_level), do: points_at(to_level) - points_at(from_level)

  @doc """
  Trait points granted by leveling from `from_level` to `to_level`.
  """
  @spec trait_gain(pos_integer(), pos_integer()) :: non_neg_integer()
  def trait_gain(from_level, to_level),
    do: trait_points_at(to_level) - trait_points_at(from_level)

  @doc """
  Status-point cost to raise a stat by one from its current `value`.
  """
  @spec cost_to_raise(non_neg_integer()) :: pos_integer()
  def cost_to_raise(value), do: Mechanics.stat_cost().cost_to_raise(value)

  @doc """
  Client-visible cost of the next primary-stat increase, or zero at the job's cap.

  Spending calculations use `cost_to_raise/1` and `points_needed/2` instead.
  """
  @spec next_cost(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def next_cost(value, job_id) do
    if value >= max_parameter(job_id), do: 0, else: cost_to_raise(value)
  end

  @doc """
  Total status points to raise a stat by `increase` from `current`.
  """
  @spec points_needed(non_neg_integer(), integer()) :: non_neg_integer()
  def points_needed(_current, increase) when increase <= 0, do: 0

  def points_needed(current, increase) do
    current
    |> Range.new(current + increase - 1)
    |> Enum.reduce(0, fn value, acc -> acc + cost_to_raise(value) end)
  end

  @doc """
  Largest increase affordable with `available` points that keeps the stat at or
  below `max_param`.
  """
  @spec max_increase(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def max_increase(current, available, max_param) do
    do_max_increase(current, current, available, max_param)
  end

  @doc """
  Maximum value a primary stat can reach for the given job.

  The cap is picked by class, first match wins: baby 3rd, baby, Summoner line,
  Kagerou/Oboro/Rebellion line, trait (4th) job, 3rd job (transcendent or
  not), transcendent, then the normal cap. Mounted forms use their canonical
  job. A job absent from the loaded job database has a cap of 0, so a
  pre-renewal 3rd or 4th job id cannot raise stats.
  """
  @spec max_parameter(non_neg_integer()) :: non_neg_integer()
  def max_parameter(job_id) do
    case class_mapid(job_id) do
      {:ok, mapid} -> parameter_cap(mapid, job_id)
      :error -> 0
    end
  end

  @doc """
  Maximum value a trait stat can reach for the given job: the trait cap on
  trait (4th) jobs, 0 on every other job and on jobs absent from the loaded job
  database.
  """
  @spec max_trait_parameter(non_neg_integer()) :: non_neg_integer()
  def max_trait_parameter(job_id) do
    if TraitJobs.trait_job?(job_id) and match?({:ok, _}, class_mapid(job_id)),
      do: @max_trait_parameter,
      else: 0
  end

  @doc """
  Rebuilds the cached table after editing the data file in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, load())
    :ok
  end

  @spec do_max_increase(non_neg_integer(), non_neg_integer(), integer(), non_neg_integer()) ::
          non_neg_integer()
  defp do_max_increase(final, base, sp, max) when final <= max and sp >= 0 do
    do_max_increase(final + 1, base, sp - cost_to_raise(final), max)
  end

  defp do_max_increase(final, base, _sp, _max) do
    result = final - 1
    if result > base, do: result - base, else: 0
  end

  @spec class_mapid(non_neg_integer()) :: {:ok, non_neg_integer()} | :error
  defp class_mapid(job_id) do
    with {:ok, name} <- AvailableJobs.job_id_to_name(job_id),
         canonical = JobLineage.normalize(name),
         {:ok, _job} <- Jobs.by_name(canonical) do
      {:ok, JobMapid.from_job(canonical)}
    else
      _unknown -> :error
    end
  end

  @spec parameter_cap(non_neg_integer(), non_neg_integer()) :: pos_integer()
  defp parameter_cap(mapid, job_id) do
    cond do
      flag?(mapid, @jobl_baby) ->
        baby_cap(mapid)

      band(mapid, @mapid_firstmask) == @mapid_summoner ->
        @max_summoner_parameter

      band(mapid, @mapid_secondmask) in [@mapid_kagerou_oboro, @mapid_rebellion] ->
        @max_extended_parameter

      TraitJobs.trait_job?(job_id) ->
        @max_fourth_parameter

      flag?(mapid, @jobl_third) ->
        third_cap(mapid)

      flag?(mapid, @jobl_upper) ->
        @max_trans_parameter

      true ->
        @max_parameter
    end
  end

  @spec baby_cap(non_neg_integer()) :: pos_integer()
  defp baby_cap(mapid),
    do: if(flag?(mapid, @jobl_third), do: @max_baby_third_parameter, else: @max_baby_parameter)

  @spec third_cap(non_neg_integer()) :: pos_integer()
  defp third_cap(mapid),
    do: if(flag?(mapid, @jobl_upper), do: @max_third_trans_parameter, else: @max_third_parameter)

  @spec flag?(non_neg_integer(), pos_integer()) :: boolean()
  defp flag?(mapid, bit), do: band(mapid, bit) != 0

  @spec at(pos_integer()) :: {non_neg_integer(), non_neg_integer()}
  defp at(level) do
    table = table()
    Map.fetch!(table, min(level, map_size(table)))
  end

  @spec table() :: %{pos_integer() => {non_neg_integer(), non_neg_integer()}}
  defp table do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = load()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec load() :: %{pos_integer() => {non_neg_integer(), non_neg_integer()}}
  defp load do
    DataLoader.load("statpoint", @cache_file, &build/1)
  end

  @spec build([Path.t()]) :: %{pos_integer() => {non_neg_integer(), non_neg_integer()}}
  defp build(sources) do
    sources
    |> Enum.flat_map(fn source -> source |> DataLoader.parse_file() |> Enum.with_index(1) end)
    |> DataLoader.merge_by_key(&elem(&1, 1))
    |> Map.new(fn {row, level} ->
      {level, {Map.fetch!(row, "points"), Map.get(row, "trait_points", 0)}}
    end)
  end
end
