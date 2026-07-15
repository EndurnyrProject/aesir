defmodule Aesir.ZoneServer.Map.LineOfSight do
  @moduledoc """
  Integer projectile traversal matching rAthena's `path_search_long`.

  The source and destination cells are not obstruction-tested; only cells
  traversed between them can block the line.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData

  @doc "Returns whether the rAthena projectile path between two cells is clear."
  @spec clear?(MapData.t(), {integer(), integer()}, {integer(), integer()}) :: boolean()
  def clear?(%MapData{} = map_data, {from_x, from_y}, {to_x, to_y}) do
    clear?(map_data, {from_x, from_y}, {to_x, to_y}, fn map, x, y ->
      not MapData.check_cell(map, x, y, :chk_noreach)
    end)
  end

  @spec clear?(String.t(), {integer(), integer()}, {integer(), integer()}) :: boolean()
  def clear?(map_name, {from_x, from_y}, {to_x, to_y}) when is_binary(map_name) do
    clear?(map_name, {from_x, from_y}, {to_x, to_y}, fn _map, x, y ->
      not Cell.blocks_projectiles?(map_name, x, y)
    end)
  end

  defp clear?(map, {from_x, from_y}, {to_x, to_y}, clear_cell?) do
    {from_x, from_y, to_x, to_y, dx} =
      if to_x < from_x,
        do: {to_x, to_y, from_x, from_y, from_x - to_x},
        else: {from_x, from_y, to_x, to_y, to_x - from_x}

    dy = to_y - from_y
    weight = max(dx, abs(dy))

    clear_step?(map, {from_x, from_y}, {to_x, to_y}, {dx, dy}, {0, 0}, weight, clear_cell?)
  end

  defp clear_step?(_map, destination, destination, _delta, _accumulated, _weight, _clear_cell?),
    do: true

  defp clear_step?(map, {x, y}, destination, {dx, dy} = delta, {wx, wy}, weight, clear_cell?) do
    {x, wx} = advance_x(x, wx + dx, weight)
    {y, wy} = advance_y(y, wy + dy, weight)

    ({x, y} == destination or clear_cell?.(map, x, y)) and
      clear_step?(map, {x, y}, destination, delta, {wx, wy}, weight, clear_cell?)
  end

  defp advance_x(x, wx, weight) when wx >= weight, do: {x + 1, wx - weight}
  defp advance_x(x, wx, _weight), do: {x, wx}

  defp advance_y(y, wy, weight) when wy >= weight, do: {y + 1, wy - weight}
  defp advance_y(y, wy, weight) when wy < 0, do: {y - 1, wy + weight}
  defp advance_y(y, wy, _weight), do: {y, wy}
end
