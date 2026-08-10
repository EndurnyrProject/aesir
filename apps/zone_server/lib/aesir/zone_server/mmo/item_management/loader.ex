defmodule Aesir.ZoneServer.Mmo.ItemManagement.Loader do
  @moduledoc """
  Builds the item index from our-schema YAML files in a data directory.

  Parses every `*.yml` in the directory into `ItemDefinition` structs and indexes
  them by id and aegis name. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @type index :: %{
          all: [ItemDefinition.t()],
          by_id: %{integer() => ItemDefinition.t()},
          by_aegis: %{String.t() => ItemDefinition.t()}
        }

  @cache_file "items_v3.etf"
  @overrides_file "script_overrides.yml"

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
    {override_sources, def_sources} =
      Enum.split_with(sources, &(Path.basename(&1) == @overrides_file))

    overrides = parse_overrides(override_sources)

    def_sources
    |> Enum.flat_map(&DataLoader.parse_file/1)
    |> Enum.map(&to_struct!/1)
    |> Enum.map(&apply_override(&1, overrides))
  end

  @spec parse_overrides([Path.t()]) :: %{integer() => String.t()}
  defp parse_overrides(sources) do
    sources
    |> Enum.flat_map(&DataLoader.parse_file/1)
    |> Map.new(fn %{"id" => id, "on_use" => on_use} -> {id, on_use} end)
  end

  @spec apply_override(ItemDefinition.t(), %{integer() => String.t()}) :: ItemDefinition.t()
  defp apply_override(definition, overrides) do
    case Map.fetch(overrides, definition.id) do
      {:ok, on_use} -> %{definition | on_use: on_use}
      :error -> definition
    end
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
  defp convert(:attack_element, v) when is_binary(v), do: String.to_atom(v)
  defp convert(:jobs, v), do: Enum.map(v, &String.to_atom/1)
  defp convert(:locations, v), do: Enum.map(v, &String.to_atom/1)
  defp convert(:on_equip, v), do: EquipScript.parse!(v)
  defp convert(_key, v), do: v
end
