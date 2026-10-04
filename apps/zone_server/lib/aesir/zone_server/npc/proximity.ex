defmodule Aesir.ZoneServer.Npc.Proximity do
  @moduledoc """
  Touch-area proximity lookup over the NPC and warp indexes in both game modes.

  Checks rectangle edges, including single-cell warps, rather than requiring
  the NPC's center to lie inside the search box.
  """

  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  @doc "True when a warp portal or NPC touch area covers any cell within `range` of `{x, y}`."
  @spec touch_area_within?(String.t(), integer(), integer(), non_neg_integer()) :: boolean()
  def touch_area_within?(map, x, y, range) do
    xr = (x - range)..(x + range)
    yr = (y - range)..(y + range)

    Enum.any?(Registry.touch_rects(map), fn {_gid, nx, ny} -> intersects?(xr, yr, nx, ny) end) or
      warp_within?(map, xr, yr)
  end

  defp warp_within?(map, xr, yr) do
    case Warps.for_map(map) do
      {:ok, warps} ->
        Enum.any?(warps, fn %Warp{x: x, y: y, xs: xs, ys: ys} ->
          intersects?(xr, yr, (x - xs)..(x + xs), (y - ys)..(y + ys))
        end)

      :error ->
        false
    end
  end

  defp intersects?(xr, yr, nx, ny),
    do: not Range.disjoint?(xr, nx) and not Range.disjoint?(yr, ny)
end
