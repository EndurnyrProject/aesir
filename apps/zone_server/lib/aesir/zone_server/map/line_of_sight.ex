defmodule Aesir.ZoneServer.Map.LineOfSight do
  @moduledoc """
  Integer straight-line traversal matching rAthena's `path_search_long`.

  The source and destination cells are not obstruction-tested; only the cells
  crossed between them can block the line. Each visited cell is checked against
  the previous one, so a walkability predicate can enforce the no-corner-cut
  rule on diagonal steps.
  """

  alias Aesir.ZoneServer.Map.Cell

  @doc "Returns whether the rAthena projectile path between two cells is clear."
  @spec clear?(String.t(), {integer(), integer()}, {integer(), integer()}) :: boolean()
  def clear?(map_name, {from_x, from_y}, {to_x, to_y}) when is_binary(map_name) do
    walk?(map_name, {from_x, from_y}, {to_x, to_y}, fn _map, _prev, {x, y} ->
      not Cell.blocks_projectiles?(map_name, x, y)
    end)
  end

  @doc """
  Returns whether a unit can walk the straight line between two cells.

  Like `clear?/3`, the source and destination cells are not tested; only the
  cells traversed between them can block the line. Each step is validated with
  `Cell.step_traversable?/3`, so a diagonal step is rejected when it would cut
  the corner between two blocked cells - the same rule pathfinding and unit
  movement enforce. Used by charge-style movement that runs a unit across the
  ground toward its target.
  """
  @spec walkable?(String.t(), {integer(), integer()}, {integer(), integer()}) :: boolean()
  def walkable?(map_name, {from_x, from_y}, {to_x, to_y}) when is_binary(map_name) do
    walk?(map_name, {from_x, from_y}, {to_x, to_y}, fn _map, prev, cell ->
      Cell.step_traversable?(map_name, prev, cell)
    end)
  end

  defp walk?(map_name, {from_x, from_y}, {to_x, to_y}, clear_step?) do
    {from_x, from_y, to_x, to_y, dx} =
      if to_x < from_x,
        do: {to_x, to_y, from_x, from_y, from_x - to_x},
        else: {from_x, from_y, to_x, to_y, to_x - from_x}

    dy = to_y - from_y
    weight = max(dx, abs(dy))

    walk_step?(map_name, {from_x, from_y}, {to_x, to_y}, {dx, dy}, {0, 0}, weight, clear_step?)
  end

  defp walk_step?(_map, destination, destination, _delta, _accumulated, _weight, _clear_step?),
    do: true

  defp walk_step?(
         map,
         {x, y} = prev,
         destination,
         {dx, dy} = delta,
         {wx, wy},
         weight,
         clear_step?
       ) do
    {nx, wx} = advance_x(x, wx + dx, weight)
    {ny, wy} = advance_y(y, wy + dy, weight)

    ({nx, ny} == destination or clear_step?.(map, prev, {nx, ny})) and
      walk_step?(map, {nx, ny}, destination, delta, {wx, wy}, weight, clear_step?)
  end

  defp advance_x(x, wx, weight) when wx >= weight, do: {x + 1, wx - weight}
  defp advance_x(x, wx, _weight), do: {x, wx}

  defp advance_y(y, wy, weight) when wy >= weight, do: {y + 1, wy - weight}
  defp advance_y(y, wy, weight) when wy < 0, do: {y - 1, wy + weight}
  defp advance_y(y, wy, _weight), do: {y, wy}
end
