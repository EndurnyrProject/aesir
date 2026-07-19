defmodule Aesir.ZoneServer.Mmo.MobManagement.Loader do
  @moduledoc """
  Builds the mob index from our-schema YAML files in a data directory.

  Parses every `*.yml` into `MobDefinition` structs and indexes them by id and
  aegis name. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`. Plain
  functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  @type index :: %{
          all: [MobDefinition.t()],
          by_id: %{integer() => MobDefinition.t()},
          by_name: %{String.t() => MobDefinition.t()}
        }

  # Version-suffixed: the cache stores built structs, so a shape change (new
  # field, new convert/2 clause) must invalidate every existing cache. Freshness
  # is mtime-based and cannot detect that the cache was built by older code.
  @cache_file "mobs_v3.etf"

  @field_names MobDefinition
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @spec load(Path.t()) :: index()
  def load(dir), do: dir |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [MobDefinition.t()]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_struct!/1)
  end

  @spec index([MobDefinition.t()]) :: index()
  defp index(defs) do
    %{
      all: defs,
      by_id: Map.new(defs, &{&1.id, &1}),
      by_name: Map.new(defs, &{&1.aegis_name, &1})
    }
  end

  @spec to_struct!(map()) :: MobDefinition.t()
  defp to_struct!(yaml_map) do
    {element, rest} = pop_element(yaml_map)

    attrs =
      rest
      |> Map.new(fn {k, v} ->
        key = Map.fetch!(@field_names, k)
        {key, convert(key, v)}
      end)
      |> Map.put(:element, element)

    struct!(MobDefinition, attrs)
  end

  # The split `element`/`element_level` YAML fields collapse into the
  # `{element_atom, level}` tuple the struct and consumers expect.
  @spec pop_element(map()) :: {{atom(), integer()}, map()}
  defp pop_element(yaml_map) do
    {element, rest} = Map.pop!(yaml_map, "element")
    {level, rest} = Map.pop(rest, "element_level", 1)
    {{String.to_atom(element), level}, rest}
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:size, v), do: String.to_atom(v)
  # "demihuman" is the existing on-disk spelling (priv/db/mobs/mobs.yml); normalized
  # here to :demi_human to match Combat.RaceModifiers without regenerating the YAML.
  defp convert(:race, "demihuman"), do: :demi_human
  defp convert(:race, v), do: String.to_atom(v)
  defp convert(:modes, v), do: Enum.map(v, &String.to_atom/1)
  defp convert(:stats, v), do: Map.new(v, fn {k, n} -> {String.to_atom(k), n} end)
  defp convert(:drops, v), do: Enum.map(v, &to_drop!/1)
  defp convert(:mvp_drops, v), do: Enum.map(v, &to_drop!/1)
  defp convert(_key, v), do: v

  @spec to_drop!(map()) :: MobDrop.t()
  defp to_drop!(drop) do
    struct!(MobDrop, Map.new(drop, fn {k, v} -> {String.to_atom(k), v} end))
  end
end
