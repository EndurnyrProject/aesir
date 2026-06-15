defmodule Aesir.ZoneServer.Mmo.JobManagement.Loader do
  @moduledoc """
  Builds the job index from our-schema YAML files in a data directory.

  Parses every `*.yml` into `Job` structs and indexes them by id and name. Level
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

  @cache_file "jobs.etf"

  @field_names Job
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @level_tables [:base_hp, :base_sp, :base_ap, :base_exp, :job_exp]

  @spec load(Path.t()) :: index()
  def load(dir), do: dir |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [Job.t()]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_struct!/1)
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

    struct!(Job, attrs)
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:name, v), do: String.to_atom(v)
  defp convert(key, v) when key in @level_tables, do: to_level_map(v)
  defp convert(:bonus_stats, v), do: Map.new(v, &{&1["level"], to_bonus(&1)})
  defp convert(:base_aspd, v), do: struct!(Job.BaseAspd, atomize_keys(v))
  defp convert(_key, v), do: v

  @spec to_level_map([non_neg_integer()]) :: %{non_neg_integer() => non_neg_integer()}
  defp to_level_map(list) do
    list |> Enum.with_index(1) |> Map.new(fn {value, level} -> {level, value} end)
  end

  @spec to_bonus(map()) :: Job.BonusStats.t()
  defp to_bonus(entry), do: struct!(Job.BonusStats, atomize_keys(entry))

  @spec atomize_keys(map()) :: map()
  defp atomize_keys(map), do: Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
end
