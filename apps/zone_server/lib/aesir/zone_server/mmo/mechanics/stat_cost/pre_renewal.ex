defmodule Aesir.ZoneServer.Mmo.Mechanics.StatCost.PreRenewal do
  @moduledoc """
  Pre-renewal status-point costs and parameter caps.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.StatCost

  @impl true
  @spec cost_to_raise(non_neg_integer()) :: pos_integer()
  def cost_to_raise(value), do: 1 + div(value + 9, 10)

  @impl true
  @spec max_parameter(non_neg_integer()) :: pos_integer()
  def max_parameter(_job_id), do: 99

  @impl true
  @spec max_trait_parameter(non_neg_integer()) :: non_neg_integer()
  def max_trait_parameter(_job_id), do: 0
end
