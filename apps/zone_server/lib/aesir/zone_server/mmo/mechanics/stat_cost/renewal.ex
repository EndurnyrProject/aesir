defmodule Aesir.ZoneServer.Mmo.Mechanics.StatCost.Renewal do
  @moduledoc """
  Renewal status-point costs.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.StatCost

  @impl true
  @spec cost_to_raise(non_neg_integer()) :: pos_integer()
  def cost_to_raise(value) when value < 100, do: 2 + div(value - 1, 10)
  def cost_to_raise(value), do: 16 + 4 * div(value - 100, 5)
end
