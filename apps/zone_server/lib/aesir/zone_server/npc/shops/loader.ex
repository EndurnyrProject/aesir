defmodule Aesir.ZoneServer.Npc.Shops.Loader do
  @moduledoc """
  Builds the per-map shop index from our-schema YAML files in the shops domain.

  Each YAML document is a flat list of shop placements; every shop carries its
  own `map` field, so the index groups them by map. An item's YAML `id` maps to
  the buy-list `nameid`, and an omitted `price` becomes `nil` (the loader keeps
  the override-or-fallback decision for the pure shop core). Cache mechanics
  live in `Aesir.ZoneServer.Mmo.DataLoader`. Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Npc.Shop

  @type index :: %{by_map: %{String.t() => [Shop.t()]}}

  @cache_file "shops.etf"

  @spec load() :: index()
  def load, do: "shops" |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [Shop.t()]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_shop!/1)
  end

  @spec index([Shop.t()]) :: index()
  defp index(shops), do: %{by_map: Enum.group_by(shops, & &1.map)}

  @spec to_shop!(map()) :: Shop.t()
  defp to_shop!(entry) do
    %Shop{
      id: Map.fetch!(entry, "id"),
      map: Map.fetch!(entry, "map"),
      x: Map.fetch!(entry, "x"),
      y: Map.fetch!(entry, "y"),
      dir: Map.fetch!(entry, "dir"),
      sprite: Map.fetch!(entry, "sprite"),
      name: Map.get(entry, "name", ""),
      items: entry |> Map.get("items", []) |> Enum.map(&to_item!/1),
      discount: Map.get(entry, "discount", true)
    }
  end

  @spec to_item!(map()) :: Shop.item()
  defp to_item!(item) do
    %{nameid: Map.fetch!(item, "id"), price: Map.get(item, "price")}
  end
end
