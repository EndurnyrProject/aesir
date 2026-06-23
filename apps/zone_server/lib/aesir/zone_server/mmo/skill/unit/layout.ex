defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Layout do
  @moduledoc """
  Pure helpers computing skill-unit footprint cell-sets from a center and shape.

  Keeps footprint geometry in one place. Only the filled Chebyshev square is
  needed now (Storm Gust's 5x5); line and single-cell shapes drop in here later.
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
end
