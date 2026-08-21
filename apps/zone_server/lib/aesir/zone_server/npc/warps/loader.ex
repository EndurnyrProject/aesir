defmodule Aesir.ZoneServer.Npc.Warps.Loader do
  @moduledoc """
  Builds the per-map warp index from our-schema YAML files in the warps domain.

  Each YAML document is a flat list of warp placements; every warp carries its
  own `map` field, so the index groups them by map. Cache mechanics live in
  `Aesir.ZoneServer.Mmo.DataLoader`. Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Npc.Warp

  @type index :: %{by_map: %{String.t() => [Warp.t()]}}

  @cache_file "warps.etf"

  @spec load() :: index()
  def load, do: "warps" |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [Warp.t()]
  defp build(sources) do
    sources |> Enum.flat_map(&DataLoader.parse_file/1) |> Enum.map(&to_warp!/1)
  end

  @spec index([Warp.t()]) :: index()
  defp index(warps) do
    by_map = warps |> Enum.group_by(& &1.map)
    %{by_map: by_map}
  end

  @spec to_warp!(map()) :: Warp.t()
  defp to_warp!(entry) do
    to = Map.fetch!(entry, "to")

    %Warp{
      id: Map.fetch!(entry, "id"),
      map: Map.fetch!(entry, "map"),
      x: Map.fetch!(entry, "x"),
      y: Map.fetch!(entry, "y"),
      xs: Map.get(entry, "xs", 0),
      ys: Map.get(entry, "ys", 0),
      sprite: Map.fetch!(entry, "sprite"),
      name: Map.get(entry, "name", ""),
      to_map: Map.fetch!(to, "map"),
      to_x: Map.fetch!(to, "x"),
      to_y: Map.fetch!(to, "y")
    }
  end
end
