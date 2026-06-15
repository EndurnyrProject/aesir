defmodule Aesir.ZoneServer.Mmo.ItemManagement.Loader do
  @moduledoc """
  Builds the item index from our-schema YAML files in a data directory.

  Parses every `*.yml` in the directory into `ItemDefinition` structs and indexes
  them by id and aegis name. A compact `.etf` cache under `<dir>/.cache/` is
  reused while it is newer than every source file, so warm boots skip YAML
  parsing entirely. Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @type index :: %{
          all: [ItemDefinition.t()],
          by_id: %{integer() => ItemDefinition.t()},
          by_aegis: %{String.t() => ItemDefinition.t()}
        }

  @cache_dir ".cache"
  @cache_file "items.etf"

  # Valid YAML keys -> struct field atoms. Sourced from the struct so the atoms
  # are guaranteed to exist regardless of load order, and unknown keys raise.
  @field_names ItemDefinition
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @spec load(Path.t()) :: index()
  def load(dir) do
    sources = dir |> Path.join("*.yml") |> Path.wildcard()

    if sources == [] do
      raise "no item data files in #{dir}; run `mix aesir.import.items`"
    end

    cache = Path.join([dir, @cache_dir, @cache_file])

    defs =
      if cache_fresh?(cache, sources) do
        cache |> File.read!() |> :erlang.binary_to_term()
      else
        built = sources |> Enum.flat_map(&parse_file/1) |> Enum.map(&to_struct!/1)
        write_cache!(cache, built)
        built
      end

    index(defs)
  end

  @spec index([ItemDefinition.t()]) :: index()
  defp index(defs) do
    %{
      all: defs,
      by_id: Map.new(defs, &{&1.id, &1}),
      by_aegis: Map.new(defs, &{&1.aegis_name, &1})
    }
  end

  @spec cache_fresh?(Path.t(), [Path.t()]) :: boolean()
  defp cache_fresh?(cache, sources) do
    File.exists?(cache) and mtime(cache) >= sources |> Enum.map(&mtime/1) |> Enum.max()
  end

  @spec mtime(Path.t()) :: integer()
  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  @spec parse_file(Path.t()) :: [map()]
  defp parse_file(path), do: YamlElixir.read_from_file!(path)

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

  @spec write_cache!(Path.t(), [ItemDefinition.t()]) :: :ok
  defp write_cache!(cache, defs) do
    File.mkdir_p!(Path.dirname(cache))
    File.write!(cache, :erlang.term_to_binary(defs))
  end
end
