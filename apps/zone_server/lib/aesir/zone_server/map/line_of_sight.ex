defmodule Aesir.ZoneServer.Map.LineOfSight do
  @moduledoc """
  Integer projectile traversal matching rAthena's `path_search_long`.

  The source and destination cells are not obstruction-tested; only cells
  traversed between them can block the line.
  """

  alias Aesir.ZoneServer.Map.MapData

  @doc "Returns whether the rAthena projectile path between two cells is clear."
  @spec clear?(MapData.t(), {integer(), integer()}, {integer(), integer()}) :: boolean()
  def clear?(map_data, {from_x, from_y}, {to_x, to_y}) do
    {from_x, from_y, to_x, to_y, dx} =
      if to_x < from_x,
        do: {to_x, to_y, from_x, from_y, from_x - to_x},
        else: {from_x, from_y, to_x, to_y, to_x - from_x}

    dy = to_y - from_y
    weight = max(dx, abs(dy))

    clear_step?(map_data, {from_x, from_y}, {to_x, to_y}, {dx, dy}, {0, 0}, weight)
  end

  defp clear_step?(_map_data, destination, destination, _delta, _accumulated, _weight),
    do: true

  defp clear_step?(map_data, {x, y}, destination, {dx, dy} = delta, {wx, wy}, weight) do
    {x, wx} = advance_x(x, wx + dx, weight)
    {y, wy} = advance_y(y, wy + dy, weight)

    ({x, y} == destination or not MapData.check_cell(map_data, x, y, :chk_noreach)) and
      clear_step?(map_data, {x, y}, destination, delta, {wx, wy}, weight)
  end

  defp advance_x(x, wx, weight) when wx >= weight, do: {x + 1, wx - weight}
  defp advance_x(x, wx, _weight), do: {x, wx}

  defp advance_y(y, wy, weight) when wy >= weight, do: {y + 1, wy - weight}
  defp advance_y(y, wy, weight) when wy < 0, do: {y - 1, wy + weight}
  defp advance_y(y, wy, _weight), do: {y, wy}
end
