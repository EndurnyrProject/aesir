defmodule Aesir.ZoneServer.Mmo.Woe.CastleDb.Loader do
  @moduledoc """
  Builds the castle index from our-schema YAML files in the castles domain.

  Parses every source into `Castle` structs, converting the list-form
  `emperium`/`respawn` coordinates into `{x, y}` tuples, and indexes them by id
  and map name. Cache mechanics live in the caller's `:persistent_term` slot.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle

  @type index :: %{
          all: [Castle.t()],
          by_id: %{non_neg_integer() => Castle.t()},
          by_map: %{String.t() => Castle.t()}
        }

  @field_names Castle
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @spec load() :: index()
  def load do
    "castles"
    |> Source.sources()
    |> Enum.flat_map(&YamlElixir.read_from_file!/1)
    |> Enum.map(&to_castle!/1)
    |> DataLoader.merge_by_key(& &1.id)
    |> index()
  end

  @spec index([Castle.t()]) :: index()
  defp index(castles) do
    %{
      all: castles,
      by_id: Map.new(castles, &{&1.id, &1}),
      by_map: Map.new(castles, &{&1.map, &1})
    }
  end

  @spec to_castle!(map()) :: Castle.t()
  defp to_castle!(yaml_map) do
    attrs =
      Map.new(yaml_map, fn {key, value} ->
        field = Map.fetch!(@field_names, key)
        {field, convert(field, value)}
      end)

    struct!(Castle, attrs)
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:emperium, [x, y]), do: {x, y}
  defp convert(:respawn, [x, y]), do: {x, y}
  defp convert(_field, value), do: value
end
