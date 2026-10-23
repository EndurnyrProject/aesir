defmodule Aesir.ZoneServer.Mmo.ItemDrop.FloorCell do
  @moduledoc """
  Where a script's floor item lands: one of the eight cells around the target,
  tried row by row with each axis' direction picked at random, the first that
  is passable and not within 5 cells of the map edge; the target cell itself
  when none is.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache

  @edge 5

  @doc "The cell an item placed at `{x, y}` on `map_name` lands on."
  @spec around(String.t(), integer(), integer(), (pos_integer() -> pos_integer())) ::
          {integer(), integer()}
  def around(map_name, x, y, rng \\ &:rand.uniform/1) do
    mirror_x = if rng.(2) == 2, do: -1, else: 1
    mirror_y = if rng.(2) == 2, do: -1, else: 1

    candidates =
      for i <- -1..1, j <- -1..1, i != 0 or j != 0, do: {x + mirror_x * i, y + mirror_y * j}

    case MapCache.get(map_name) do
      {:ok, map} -> Enum.find(candidates, {x, y}, fn {cx, cy} -> free?(map, map_name, cx, cy) end)
      _ -> {x, y}
    end
  end

  defp free?(map, map_name, x, y) do
    x >= @edge and x <= map.xs - @edge and y >= @edge and y <= map.ys - @edge and
      Cell.traversable?(map_name, x, y)
  end
end
