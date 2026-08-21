defmodule Aesir.ZoneServer.Mmo.QuestManagement.Loader do
  @moduledoc """
  Builds the quest index from our-schema YAML files in the quests domain.

  Parses every source into `QuestDefinition` structs and
  indexes them by id. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition

  @type index :: %{
          all: [QuestDefinition.t()],
          by_id: %{integer() => QuestDefinition.t()}
        }

  @cache_file "quests.etf"

  @field_names QuestDefinition
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @spec load() :: index()
  def load, do: "quests" |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [QuestDefinition.t()]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_struct!/1)
  end

  @spec index([QuestDefinition.t()]) :: index()
  defp index(defs) do
    %{
      all: defs,
      by_id: Map.new(defs, &{&1.id, &1})
    }
  end

  @spec to_struct!(map()) :: QuestDefinition.t()
  defp to_struct!(yaml_map) do
    attrs =
      Map.new(yaml_map, fn {k, v} ->
        key = Map.fetch!(@field_names, k)
        {key, convert(key, v)}
      end)

    struct!(QuestDefinition, attrs)
  end

  @spec convert(atom(), term()) :: term()
  defp convert(:targets, v), do: Enum.map(v, &atomize_keys/1)
  defp convert(:drops, v), do: Enum.map(v, &atomize_keys/1)
  defp convert(_key, v), do: v

  @spec atomize_keys(map()) :: map()
  defp atomize_keys(map), do: Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
end
