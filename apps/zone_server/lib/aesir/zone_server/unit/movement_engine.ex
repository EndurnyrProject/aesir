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
  @type movement_budget :: float()
  @type consumed_budget :: float()

  @doc """
  Calculates movement budget based on elapsed time and walk speed.

  Walk Speed is milliseconds per cell (RO convention)
  So cells covered = elapsed_ms / walk_speed

  ## Parameters
    - elapsed_ms: Time elapsed since movement started (milliseconds)
    - walk_speed: Entity's walk speed in ms per cell (higher = slower, following RO convention)
    
  ## Returns
    - Movement budget (float) representing how much distance can be covered
  """
  @spec calculate_movement_budget(integer(), integer()) :: movement_budget()
  def calculate_movement_budget(elapsed_ms, walk_speed) do
    elapsed_ms / walk_speed
  end

  @doc """
  Consumes a movement path based on available budget.

  Moves along the path consuming budget for each step until either:
  - The path is exhausted
  - The budget is exhausted

  ## Parameters
    - current_x: Current X position
    - current_y: Current Y position  
    - path: List of {x, y} coordinates to follow
    - budget: Available movement budget
    
  ## Returns
    - {new_x, new_y, remaining_path, consumed_budget}
  """
  @spec consume_path_with_budget(integer(), integer(), path(), movement_budget()) ::
          {integer(), integer(), path(), consumed_budget()}
  def consume_path_with_budget(x, y, path, budget) do
    do_consume_path(x, y, path, budget, 0.0)
  end

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
  Gets the straight movement cost constant.
  """
  @spec straight_cost() :: float()
  def straight_cost, do: @straight_cost

  @doc """
  Gets the diagonal movement cost constant.
  """
  @spec diagonal_cost() :: float()
  def diagonal_cost, do: @diagonal_cost

  defp do_consume_path(x, y, [], _budget, consumed) do
    {x, y, [], consumed}
  end

  defp do_consume_path(x, y, path, budget, consumed) when budget <= 0 do
    {x, y, path, consumed}
  end

  defp do_consume_path(x, y, [{next_x, next_y} | rest], budget, consumed) do
    move_cost = get_movement_cost({x, y}, {next_x, next_y})

    if move_cost <= budget do
      do_consume_path(next_x, next_y, rest, budget - move_cost, consumed + move_cost)
    else
      {x, y, [{next_x, next_y} | rest], consumed}
    end
  end
end
