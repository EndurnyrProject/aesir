defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.OreTable do
  @moduledoc """
  Runtime catalog of ore discovery items and their rates.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader

  @pt_key __MODULE__

  @typedoc "An ore item id and its discovery rate."
  @type entry() :: {integer(), integer()}

  @doc "Returns every ore discovery item and rate."
  @spec entries() :: [entry()]
  def entries, do: index()

  @doc "Rebuilds the cached ore table from disk."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
  end

  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  defp build do
    "produce/ore_discovery.yml"
    |> Source.sources()
    |> Enum.flat_map(&YamlElixir.read_from_file!/1)
    |> DataLoader.merge_by_key(& &1["item_id"])
    |> Enum.map(fn %{"item_id" => item_id, "rate" => rate} -> {item_id, rate} end)
  end
end
