defmodule Aesir.ZoneServer.Mmo.Skill.Loader do
  @moduledoc """
  Builds the skill index from our-schema YAML files in a data directory.

  Parses every `*.yml` into `Skill.Definition` structs and indexes them by id
  and name. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`.
  """
  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @type index :: %{
          all: [Definition.t()],
          by_id: %{integer() => Definition.t()},
          by_name: %{atom() => Definition.t()}
        }

  @cache_file "skills.etf"

  @field_names Definition
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @spec load(Path.t()) :: index()
  def load(dir), do: dir |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [Definition.t()]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_struct!/1)
  end

  @spec index([Definition.t()]) :: index()
  defp index(defs) do
    %{
      all: defs,
      by_id: Map.new(defs, &{&1.id, &1}),
      by_name: Map.new(defs, &{&1.name, &1})
    }
  end

  @spec to_struct!(map()) :: Definition.t()
  defp to_struct!(yaml_map) do
    attrs =
      Map.new(yaml_map, fn {k, v} ->
        key = Map.fetch!(@field_names, k)
        {key, convert(key, v)}
      end)

    struct!(Definition, attrs)
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:name, v), do: String.to_atom(v)
  defp convert(:target_type, v), do: String.to_atom(v)
  defp convert(:damage_type, v), do: String.to_atom(v)
  defp convert(_key, v), do: v
end
