defmodule Aesir.ZoneServer.Mmo.Mechanics.StatCost.PreRenewal do
  @moduledoc """
  Pre-renewal status-point costs.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.StatCost

  @impl true
  @spec cost_to_raise(non_neg_integer()) :: pos_integer()
  def cost_to_raise(value), do: 1 + div(value + 9, 10)
end
