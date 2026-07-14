defmodule Aesir.ZoneServer.Geometry do
  @moduledoc """
  Utility module for spatial calculations and grid operations.
  Pure functions for geometry, direction, and cell calculations.
  """

  @doc """
  Calculates direction from one point to another.
  Returns a direction value from 0-7 representing 8 compass directions.

  Uses the RO sprite-frame convention expected by the Lifthrasir client
  (matching its `Direction::from_movement_vector`):
  - 0: South
  - 1: Southwest
  - 2: West
  - 3: Northwest
  - 4: North
  - 5: Northeast
  - 6: East
  - 7: Southeast
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def calculate_direction(from_x, from_y, to_x, to_y) do
    dx = to_x - from_x
    dy = to_y - from_y

    cond do
      dx == 0 and dy < 0 -> 0
      dx > 0 and dy < 0 -> 7
      dx > 0 and dy == 0 -> 6
      dx > 0 and dy > 0 -> 5
      dx == 0 and dy > 0 -> 4
      dx < 0 and dy > 0 -> 3
      dx < 0 and dy == 0 -> 2
      dx < 0 and dy < 0 -> 1
      true -> 0
    end
  end

  @doc """
  Calculates Manhattan distance between two points.
  Useful for grid-based movement.
  """
  def manhattan_distance(x1, y1, x2, y2) do
    abs(x2 - x1) + abs(y2 - y1)
  end

  @doc """
  Calculates Chebyshev distance between two points.
  This is the correct distance for tile-based games like Ragnarok Online,
  where diagonal movement is allowed and counts as 1 cell distance.

  Also known as "chess king distance" or "maximum metric".
  """
  def chebyshev_distance(x1, y1, x2, y2) do
    max(abs(x2 - x1), abs(y2 - y1))
  end

  @doc """
  Checks if a point is within tile-based range using Chebyshev distance.
  This is the correct range check for Ragnarok Online tile-based movement.
  """
  def in_tile_range?(x1, y1, x2, y2, range) do
    chebyshev_distance(x1, y1, x2, y2) <= range
  end
end
