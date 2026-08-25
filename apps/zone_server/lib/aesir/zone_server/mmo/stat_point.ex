defmodule Aesir.ZoneServer.Mmo.StatPoint do
  @moduledoc """
  Status-point table and mode-specific cost formulas.

  The cumulative status-point table (`points_at/1`, `gain/2`) is loaded as data
  and cached in `:persistent_term`, mirroring `JobManagement.Jobs`. The spend
  cost and parameter caps delegate to the active mechanics implementation.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.Mechanics

  @pt_key __MODULE__
  @cache_file "statpoint_v2.etf"

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
  the table's maximum level. 0 through level 200.
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
  """
  @spec max_parameter(non_neg_integer()) :: pos_integer()
  def max_parameter(job_id), do: Mechanics.stat_cost().max_parameter(job_id)

  @doc """
  Maximum value a trait stat can reach for the given job.
  """
  @spec max_trait_parameter(non_neg_integer()) :: non_neg_integer()
  def max_trait_parameter(job_id), do: Mechanics.stat_cost().max_trait_parameter(job_id)

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
    |> Map.new(fn {%{"points" => points, "trait_points" => trait_points}, level} ->
      {level, {points, trait_points}}
    end)
  end
end
