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
end
