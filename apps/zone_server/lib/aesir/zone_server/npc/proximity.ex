defmodule Aesir.ZoneServer.Npc.Proximity do
  @moduledoc """
  Proximity lookups over the NPC, warp and shop indexes in both game modes.

  `touch_area_within?/4` checks rectangle edges, including single-cell warps,
  rather than requiring the NPC's center to lie inside the search box.
  `npc_near?/3` checks the NPC's own cell.
  """

  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.Session
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  @vend_chat_distance 3

  @doc """
  True when an NPC stands within 3 cells of `{x, y}` on `map`, counted as a
  square: a script NPC that is neither disabled nor hidden, a warp portal or a
  shop. No vending stall or chat room may be opened there.
  """
  @spec npc_near?(String.t(), integer(), integer()) :: boolean()
  def npc_near?(map, x, y) do
    near? = fn nx, ny ->
      abs(nx - x) <= @vend_chat_distance and abs(ny - y) <= @vend_chat_distance
    end

    Enum.any?(Registry.entries(), fn {_module, placement} ->
      placement.map == map and near?.(placement.x, placement.y) and
        Session.visible?(Registry.entity_id(placement))
    end) or
      Enum.any?(on_map(Warps.for_map(map)), &near?.(&1.x, &1.y)) or
      Enum.any?(on_map(Shops.for_map(map)), &near?.(&1.x, &1.y))
  end

  defp on_map({:ok, list}), do: list
  defp on_map(:error), do: []

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
