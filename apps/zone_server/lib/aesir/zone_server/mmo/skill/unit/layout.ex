defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Layout do
  @moduledoc """
  Pure helpers computing skill-unit footprint cell-sets from a center and shape.

  Keeps footprint geometry in one place: the filled Chebyshev square (Storm
  Gust's 5x5), the straight line, the direction-dependent wall (Fire Wall), and
  Grand Cross's diamond.
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
  diagonal the caster faces, so the two cases are mirror images. These are
  rAthena's eight Fire Wall layouts (`skill_init_unit_layout`).

  `y` grows northward, matching the rest of the direction code.
  """
  @spec wall(cell(), {-1..1, -1..1}) :: [cell()]
  def wall({cx, cy}, {fx, fy}) when fx == 0 or fy == 0, do: line({cx, cy}, {-fy, fx}, 1)

  # Facing north-east or south-west: the wall runs north-west to south-east.
  def wall({cx, cy}, {fx, fy}) when fx * fy > 0,
    do: for({dx, dy} <- [{-1, 1}, {-1, 0}, {0, 0}, {0, -1}, {1, -1}], do: {cx + dx, cy + dy})

  # Facing north-west or south-east: the wall runs north-east to south-west.
  def wall({cx, cy}, _facing),
    do: for({dx, dy} <- [{1, 1}, {1, 0}, {0, 0}, {0, -1}, {-1, -1}], do: {cx + dx, cy + dy})

  # rAthena's CR_GRANDCROSS layout, row by row from four cells south to four
  # north: one cell, one, three, five, nine, five, three, one, one.
  @grand_cross for {dy, half} <- [
                     {-4, 0},
                     {-3, 0},
                     {-2, 1},
                     {-1, 2},
                     {0, 4},
                     {1, 2},
                     {2, 1},
                     {3, 0},
                     {4, 0}
                   ],
                   dx <- -half..half,
                   do: {dx, dy}

  @doc """
  Returns Grand Cross's 29-cell footprint centered on `{cx, cy}`: a cross with
  arms of four cells, filled out to three cells wide two rows from the center
  and five cells wide one row from it.
  """
  @spec grand_cross(cell()) :: [cell()]
  def grand_cross({cx, cy}), do: for({dx, dy} <- @grand_cross, do: {cx + dx, cy + dy})
end
