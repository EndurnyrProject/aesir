defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Layout do
  @moduledoc """
  Pure helpers computing skill-unit footprint cell-sets from a center and shape.

  Keeps footprint geometry in one place: the filled Chebyshev square (Storm
  Gust's 5x5), the straight line, the direction-dependent wall (Fire Wall), and
  the plus/cross (Grand Cross).
  """

  @typedoc "A single map cell."
  @type cell :: {integer(), integer()}

  @doc """
  Returns the filled Chebyshev square of side `2 * radius + 1` centered on
  `{cx, cy}`: every cell with `|dx| <= radius` and `|dy| <= radius`, no
  duplicates.

  `radius` 0 yields the single center cell, `radius` 2 the 25-cell 5x5 block.
  """
  @spec square(cell(), non_neg_integer()) :: [cell()]
  def square({cx, cy}, radius) do
    for dx <- -radius..radius, dy <- -radius..radius, do: {cx + dx, cy + dy}
  end

  @doc """
  Returns a straight line of `2 * half + 1` cells centered on `{cx, cy}`, stepping
  by the unit direction `{ux, uy}` (Fire Wall's wall of cells).

  `half` 1 with direction `{1, 0}` yields the three cells `{cx-1, cy}`, `{cx, cy}`,
  `{cx+1, cy}`.
  """
  @spec line(cell(), {integer(), integer()}, non_neg_integer()) :: [cell()]
  def line({cx, cy}, {ux, uy}, half) do
    for d <- -half..half, do: {cx + d * ux, cy + d * uy}
  end

  @doc """
  Returns a wall footprint centered on `{cx, cy}` and laid perpendicular to the
  8-way `facing` the caster looked along when placing it.

  A cardinal facing gives a straight 3-cell line. A diagonal facing gives a
  5-cell staircase along the opposite diagonal: a bare 3-cell diagonal line
  leaves corner gaps a unit can slip through, so the wall doubles up on the two
  cells beside the center. Which way that staircase steps depends on which
  diagonal the caster faces, so the two cases are mirror images. A zero facing
  has no perpendicular and lays the default east-west line.

  `y` grows northward, matching the rest of the direction code.
  """
  @spec wall(cell(), {integer(), integer()}) :: [cell()]
  def wall({cx, cy}, {0, 0}), do: line({cx, cy}, {1, 0}, 1)

  def wall({cx, cy}, {fx, fy}) when fx == 0 or fy == 0, do: line({cx, cy}, {-fy, fx}, 1)

  # Facing north-east or south-west: the wall runs north-west to south-east.
  def wall({cx, cy}, {fx, fy}) when fx * fy > 0,
    do: for({dx, dy} <- [{-1, 1}, {-1, 0}, {0, 0}, {0, -1}, {1, -1}], do: {cx + dx, cy + dy})

  # Facing north-west or south-east: the wall runs north-east to south-west.
  def wall({cx, cy}, _facing),
    do: for({dx, dy} <- [{1, 1}, {1, 0}, {0, 0}, {0, -1}, {-1, -1}], do: {cx + dx, cy + dy})

  @doc """
  Returns the plus/cross shape relative to the origin `{0, 0}`: the center
  cell plus `arm_length` cells along each of the 4 cardinal directions
  (Grand Cross's footprint, always self-centered on the caster).

  `arm_length` 2 yields exactly 9 cells: the center and 2 cells in each of
  north, south, east, and west. Callers translate the result onto the map by
  adding the caster's cell to every returned offset.
  """
  @spec cross(non_neg_integer()) :: [cell()]
  def cross(arm_length) do
    arms =
      for {ux, uy} <- [{1, 0}, {-1, 0}, {0, 1}, {0, -1}],
          d <- 1..arm_length//1,
          do: {d * ux, d * uy}

    [{0, 0} | arms]
  end
end
