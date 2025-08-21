defmodule Aesir.ZoneServer.Geometry do
  @moduledoc """
  Utility module for spatial calculations and grid operations.
  Pure functions for geometry, direction, and cell calculations.
  """

  @cell_size 8

  @doc """
  Calculates direction from one point to another.
  Returns a direction value from 0-7 representing 8 compass directions.

  Direction mapping:
  - 0: North
  - 1: Northeast  
  - 2: East
  - 3: Southeast
  - 4: South
  - 5: Southwest
  - 6: West
  - 7: Northwest
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def calculate_direction(from_x, from_y, to_x, to_y) do
    dx = to_x - from_x
    dy = to_y - from_y

    cond do
      dx == 0 and dy < 0 -> 0
      dx > 0 and dy < 0 -> 1
      dx > 0 and dy == 0 -> 2
      dx > 0 and dy > 0 -> 3
      dx == 0 and dy > 0 -> 4
      dx < 0 and dy > 0 -> 5
      dx < 0 and dy == 0 -> 6
      dx < 0 and dy < 0 -> 7
      true -> 0
    end
  end

  @doc """
  Converts map coordinates to grid cell coordinates.
  Grid cells are 8x8 map units.
  """
  def to_cell_coords(x, y) do
    {div(x, @cell_size), div(y, @cell_size)}
  end

  @doc """
  Calculates which grid cells are visible from a position.
  Returns a list of {cell_x, cell_y} tuples.
  """
  def visible_cells(x, y, view_range) do
    {center_x, center_y} = to_cell_coords(x, y)

    # Calculate cell range (view_range is in map cells, we use 8x8 chunks)
    cell_range = div(view_range, @cell_size) + 1

    for cx <- (center_x - cell_range)..(center_x + cell_range),
        cy <- (center_y - cell_range)..(center_y + cell_range) do
      {cx, cy}
    end
  end

  @doc """
  Calculates the distance between two points.
  """
  def distance(x1, y1, x2, y2) do
    dx = x2 - x1
    dy = y2 - y1
    :math.sqrt(dx * dx + dy * dy)
  end

  @doc """
  Calculates Manhattan distance between two points.
  Useful for grid-based movement.
  """
  def manhattan_distance(x1, y1, x2, y2) do
    abs(x2 - x1) + abs(y2 - y1)
  end

  @doc """
  Checks if a point is within range of another point.
  """
  def in_range?(x1, y1, x2, y2, range) do
    distance(x1, y1, x2, y2) <= range
  end

  @doc """
  Gets all cells that a line from point A to B passes through.
  Useful for line-of-sight or movement path calculations.
  """
  def cells_on_path(from_x, from_y, to_x, to_y) do
    {from_cell_x, from_cell_y} = to_cell_coords(from_x, from_y)
    {to_cell_x, to_cell_y} = to_cell_coords(to_x, to_y)

    if from_cell_x == to_cell_x and from_cell_y == to_cell_y do
      [{from_cell_x, from_cell_y}]
    else
      # Get unique cells on the path
      # This is simplified - a more complex implementation would use
      # Bresenham's line algorithm for accurate cell traversal
      [{from_cell_x, from_cell_y}, {to_cell_x, to_cell_y}]
      |> Enum.uniq()
    end
  end

  @doc """
  Checks if a direction is diagonal.
  Diagonal directions are: 1 (NE), 3 (SE), 5 (SW), 7 (NW)
  """
  def is_diagonal_direction?(direction) when is_integer(direction) do
    direction in [1, 3, 5, 7]
  end

  @doc """
  Checks if movement from one position to another is diagonal.
  """
  def diagonal_move?(from_x, from_y, to_x, to_y) do
    dx = abs(to_x - from_x)
    dy = abs(to_y - from_y)
    dx == 1 and dy == 1
  end

  # Movement timing constants from rAthena
  @move_cost 10
  @move_diagonal_cost 14

  @doc """
  Calculates movement time based on direction, matching rAthena's timing.
  Diagonal moves take 1.4x longer than straight moves.
  """
  def calculate_movement_time(base_speed, from_x, from_y, to_x, to_y) do
    if diagonal_move?(from_x, from_y, to_x, to_y) do
      # Diagonal moves take longer (MOVE_DIAGONAL_COST / MOVE_COST)
      round(base_speed * @move_diagonal_cost / @move_cost)
    else
      base_speed
    end
  end

  @doc """
  Calculates movement time based on direction value, matching rAthena's timing.
  """
  def calculate_movement_time_by_direction(base_speed, direction) do
    if is_diagonal_direction?(direction) do
      round(base_speed * @move_diagonal_cost / @move_cost)
    else
      base_speed
    end
  end
end
