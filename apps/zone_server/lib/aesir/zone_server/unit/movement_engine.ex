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
