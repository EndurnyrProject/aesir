defmodule Aesir.ZoneServer.Mmo.JobManagement.Loader do
  @moduledoc """
  Builds the job index from our-schema YAML files in the jobs domain.

  Parses every source into `Job` structs and indexes them by id and name. Level
  tables are stored as plain lists from level 1 in the YAML and rehydrated into
  level-keyed maps here. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.Job

  @type index :: %{
          all: [Job.t()],
          by_id: %{non_neg_integer() => Job.t()},
          by_name: %{atom() => Job.t()}
        }

  @cache_file "jobs_v2.etf"

  @field_names Job
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @level_tables [:base_hp, :base_sp, :base_ap, :base_exp, :job_exp]

  @bonus_stat_fields [:str, :agi, :vit, :int, :dex, :luk, :pow, :sta, :wis, :spl, :con, :crt]

  @spec load() :: index()
  def load, do: "jobs" |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [Job.t()]
  defp build(sources) do
    sources
    |> Enum.flat_map(&DataLoader.parse_file/1)
    |> Enum.map(&to_struct!/1)
    |> DataLoader.merge_by_key(& &1.name)
  end

  @spec index([Job.t()]) :: index()
  defp index(defs) do
    %{
      all: defs,
      by_id: Map.new(defs, &{&1.id, &1}),
      by_name: Map.new(defs, &{&1.name, &1})
    }
  end

  @spec to_struct!(map()) :: Job.t()
  defp to_struct!(yaml_map) do
    attrs =
      Map.new(yaml_map, fn {k, v} ->
        key = Map.fetch!(@field_names, k)
        {key, convert(key, v)}
      end)

    struct!(Job, densify_bonus_stats(attrs))
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:name, v), do: String.to_atom(v)
  defp convert(key, v) when key in @level_tables, do: to_level_map(v)
  defp convert(:bonus_stats, v), do: accumulate_bonus_stats(v)
  defp convert(:base_aspd, v), do: struct!(Job.BaseAspd, atomize_keys(v))
  defp convert(_key, v), do: v

  @spec to_level_map([non_neg_integer()]) :: %{non_neg_integer() => non_neg_integer()}
  defp to_level_map(list) do
    list |> Enum.with_index(1) |> Map.new(fn {value, level} -> {level, value} end)
  end

  @spec accumulate_bonus_stats([map()]) :: %{non_neg_integer() => Job.BonusStats.t()}
  defp accumulate_bonus_stats(entries) do
    entries
    |> Enum.sort_by(& &1["level"])
    |> Enum.reduce({%{}, %Job.BonusStats{}}, fn entry, {acc, running} ->
      cumulative = accumulate(running, to_bonus(entry))
      {Map.put(acc, entry["level"], cumulative), cumulative}
    end)
    |> elem(0)
  end

  @spec accumulate(Job.BonusStats.t(), Job.BonusStats.t()) :: Job.BonusStats.t()
  defp accumulate(running, grant) do
    Enum.reduce(@bonus_stat_fields, %{running | level: grant.level}, fn field, acc ->
      Map.update!(acc, field, &(&1 + Map.fetch!(grant, field)))
    end)
  end

  @spec densify_bonus_stats(map()) :: map()
  defp densify_bonus_stats(%{bonus_stats: sparse} = attrs) when map_size(sparse) > 0 do
    last_grant = sparse |> Map.keys() |> Enum.max()
    ceiling = max(last_grant, Map.get(attrs, :max_job_level, last_grant))

    {dense, _last} =
      Enum.reduce(1..ceiling, {%{}, %Job.BonusStats{}}, fn level, {acc, prev} ->
        cumulative = Map.get(sparse, level, %{prev | level: level})
        {Map.put(acc, level, cumulative), cumulative}
      end)

    %{attrs | bonus_stats: dense}
  end

  defp densify_bonus_stats(attrs), do: attrs

  @spec to_bonus(map()) :: Job.BonusStats.t()
  defp to_bonus(entry), do: struct!(Job.BonusStats, atomize_keys(entry))

  @spec atomize_keys(map()) :: map()
  defp atomize_keys(map), do: Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
end
