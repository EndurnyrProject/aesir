defmodule Aesir.ZoneServer.Mmo.StatPoint do
  @moduledoc """
  Status-point table and renewal cost formula.

  The cumulative status-point table (`points_at/1`, `gain/2`) is loaded as data
  from `priv/db/statpoint/statpoint.yml` and cached in `:persistent_term`,
  mirroring `JobManagement.Jobs`. The spend cost (`cost_to_raise/1`,
  `points_needed/2`, `max_increase/3`) is the pure rAthena renewal formula.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader

  @pt_key __MODULE__
  @cache_file "statpoint.etf"

  @doc """
  Cumulative status points granted from base level 1 up to `level`, clamped to
  the table's maximum level.
  """
  @spec points_at(pos_integer()) :: non_neg_integer()
  def points_at(level) when level >= 1 do
    table = table()
    Map.fetch!(table, min(level, map_size(table)))
  end

  @doc """
  Status points granted by leveling from `from_level` to `to_level`.
  """
  @spec gain(pos_integer(), pos_integer()) :: non_neg_integer()
  def gain(from_level, to_level), do: points_at(to_level) - points_at(from_level)

  @doc """
  Renewal status-point cost to raise a stat by one from its current `value`.
  """
  @spec cost_to_raise(non_neg_integer()) :: pos_integer()
  def cost_to_raise(value) when value < 100, do: 2 + div(value - 1, 10)
  def cost_to_raise(value), do: 16 + 4 * div(value - 100, 5)

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
  below `max_param`. Faithful port of rAthena `pc_maxparameterincrease`.
  """
  @spec max_increase(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def max_increase(current, available, max_param) do
    do_max_increase(current, current, available, max_param)
  end

  @doc """
  Maximum value a primary stat can reach for the given job.
  """
  @spec max_parameter(non_neg_integer()) :: pos_integer()
  def max_parameter(_job_id), do: 99

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

  @spec table() :: %{pos_integer() => non_neg_integer()}
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

  @spec load() :: %{pos_integer() => non_neg_integer()}
  defp load do
    DataLoader.load(data_dir(), @cache_file, &build/1)
  end

  @spec build([Path.t()]) :: %{pos_integer() => non_neg_integer()}
  defp build(sources) do
    sources
    |> Enum.flat_map(&DataLoader.parse_file/1)
    |> Enum.with_index(1)
    |> Map.new(fn {points, level} -> {level, points} end)
  end

  @spec data_dir() :: Path.t()
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/statpoint")
end
