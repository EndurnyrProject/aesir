defmodule Aesir.ZoneServer.Mmo.ItemManagement.Loader do
  @moduledoc """
  Builds the item index from our-schema YAML files in a data directory.

  Parses every `*.yml` in the directory into `ItemDefinition` structs and indexes
  them by id and aegis name. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @type index :: %{
          all: [ItemDefinition.t()],
          by_id: %{integer() => ItemDefinition.t()},
          by_aegis: %{String.t() => ItemDefinition.t()}
        }

  @cache_file "items.etf"

  # Valid YAML keys -> struct field atoms. Sourced from the struct so the atoms
  # are guaranteed to exist regardless of load order, and unknown keys raise.
  @field_names ItemDefinition
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @spec load(Path.t()) :: index()
  def load(dir), do: dir |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [ItemDefinition.t()]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_struct!/1)
  end

  @spec index([ItemDefinition.t()]) :: index()
  defp index(defs) do
    %{
      all: defs,
      by_id: Map.new(defs, &{&1.id, &1}),
      by_aegis: Map.new(defs, &{&1.aegis_name, &1})
    }
  end

  @spec to_struct!(map()) :: ItemDefinition.t()
  defp to_struct!(yaml_map) do
    attrs =
      Map.new(yaml_map, fn {k, v} ->
        key = Map.fetch!(@field_names, k)
        {key, convert(key, v)}
      end)

    struct!(ItemDefinition, attrs)
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:type, v), do: String.to_atom(v)
  defp convert(:subtype, v) when is_binary(v), do: String.to_atom(v)
  defp convert(:jobs, v), do: Enum.map(v, &String.to_atom/1)
  defp convert(:locations, v), do: Enum.map(v, &String.to_atom/1)
  defp convert(_key, v), do: v
end
