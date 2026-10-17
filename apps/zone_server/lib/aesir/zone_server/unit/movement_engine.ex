defmodule Aesir.ZoneServer.Unit.MovementEngine do
  @moduledoc """
  Shared movement logic for all moving entities (players, mobs, etc.).

  Centralizes path consumption algorithms, movement budget calculations,
  and movement constants to eliminate duplication between entity types.
  """

  # Movement cost constants
  @straight_cost 1.0
  @diagonal_cost 1.414

  @type position :: {integer(), integer()}
  @type path :: [position()]

  @doc """
  Gets the movement cost for traveling between two adjacent positions.

  ## Parameters
    - from: Starting position {x, y}
    - to: Destination position {x, y}
    
  ## Returns
    - Movement cost (1.0 for straight, 1.414 for diagonal)
  """
  @spec get_movement_cost(position(), position()) :: float()
  def get_movement_cost({x1, y1}, {x2, y2}) do
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)

    if dx == 1 and dy == 1 do
      @diagonal_cost
    else
      @straight_cost
    end
  end

  @doc """
  Computes the timer delay, in milliseconds, before the unit reaches the next cell.

  A straight step takes the unit's `walk_speed` and a diagonal one
  `walk_speed * 14 / 10` (truncated), the walk's own step ratio; the
  `diagonal_cost/0` path-cost constant is not used for timing. It is
  read from the unit's live `walk_speed` on every step, which lets a mid-path
  speed change (Agi Up, Quagmire, mount, etc.) retime the remaining cells
  without rebuilding the path.

  ## Parameters
    - walk_speed: The unit's live walk speed (ms per straight cell)
    - from: Current position {x, y}
    - to: Next cell {x, y}

  ## Returns
    - Delay in milliseconds until the next movement tick
  """
  @spec step_delay(non_neg_integer(), position(), position()) :: non_neg_integer()
  def step_delay(walk_speed, {x1, y1}, {x2, y2}) when x1 != x2 and y1 != y2,
    do: div(walk_speed * 14, 10)

  def step_delay(walk_speed, _from, _to), do: walk_speed

  @doc """
  Gets the straight movement cost constant.
  """
  @spec straight_cost() :: float()
  def straight_cost, do: @straight_cost

  @doc """
  Gets the diagonal movement cost constant.
  """
  @spec diagonal_cost() :: float()
  def diagonal_cost, do: @diagonal_cost
end
