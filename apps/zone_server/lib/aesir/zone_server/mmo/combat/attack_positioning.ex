defmodule Aesir.ZoneServer.Mmo.Combat.AttackPositioning do
  @moduledoc """
  Pure helper for choosing where to stand when attacking a target.

  There is no global occupancy grid: both terrain walkability and unit
  occupancy are supplied by the caller as predicates, keeping this module
  pure and trivially testable. Callers build `occupied?` from whatever
  nearby-unit source they already have (e.g. `SpatialIndex`), and must
  exclude the moving unit itself so it is not blocked by its own cell.
  """

  alias Aesir.ZoneServer.Geometry

  @type cell :: {integer(), integer()}
  @type predicate :: (integer(), integer() -> boolean())

  @doc """
  Picks the best cell to attack `target` from, given the attacker is at `from`.

  A candidate cell is valid when it is:
    * within `range` (Chebyshev distance) of the target,
    * not the target's own cell,
    * walkable (per `walkable?`),
    * not occupied (per `occupied?`).

  Among valid candidates it returns the one nearest the attacker (fewest
  grid steps from `from`, Euclidean distance breaking ties), which lands the
  attacker on the near side of the target. Returns `nil` when no valid cell
  exists.
  """
  @spec adjacent_attack_cell(cell(), cell(), non_neg_integer(), predicate(), predicate()) ::
          cell() | nil
  def adjacent_attack_cell({fx, fy}, {tx, ty}, range, walkable?, occupied?) do
    candidates =
      for dx <- -range..range,
          dy <- -range..range,
          {dx, dy} != {0, 0},
          walkable?.(tx + dx, ty + dy),
          not occupied?.(tx + dx, ty + dy) do
        {tx + dx, ty + dy}
      end

    case candidates do
      [] -> nil
      cells -> Enum.min_by(cells, fn {x, y} -> approach_cost(fx, fy, x, y) end)
    end
  end

  defp approach_cost(fx, fy, x, y) do
    {Geometry.chebyshev_distance(fx, fy, x, y), squared_distance(fx, fy, x, y)}
  end

  defp squared_distance(x1, y1, x2, y2) do
    dx = x2 - x1
    dy = y2 - y1
    dx * dx + dy * dy
  end
end
