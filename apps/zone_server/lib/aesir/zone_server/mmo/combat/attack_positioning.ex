defmodule Aesir.ZoneServer.Mmo.Combat.AttackPositioning do
  @moduledoc """
  Chooses an adjoining chase destination using terrain alone.

  Units do not reserve attack cells. The approach follows the target vector,
  falling back to the first traversable adjoining cell in direction order.
  """

  @typedoc "An integer map cell."
  @type cell :: {integer(), integer()}
  @typedoc "A terrain traversability predicate."
  @type predicate :: (integer(), integer() -> boolean())

  @directions [{0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}]

  @doc "Returns the adjoining approach cell, or nil when terrain surrounds the target."
  @spec adjacent_attack_cell(cell(), cell(), predicate()) :: cell() | nil
  def adjacent_attack_cell(from, target, _walkable?) when from == target, do: from

  def adjacent_attack_cell({fx, fy}, {tx, ty}, walkable?) do
    toward = {tx - sign(tx - fx), ty - sign(ty - fy)}

    [toward | Enum.map(@directions, fn {dx, dy} -> {tx - dx, ty - dy} end)]
    |> Enum.find(fn {x, y} -> walkable?.(x, y) end)
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_n), do: 0
end
