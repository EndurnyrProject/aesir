defmodule Aesir.ZoneServer.Mmo.Mechanics.StatCost do
  @moduledoc """
  Contract for mode-specific status-point costs and parameter caps.
  """

  @callback cost_to_raise(non_neg_integer()) :: pos_integer()
  @callback max_parameter(non_neg_integer()) :: pos_integer()
  @callback max_trait_parameter(non_neg_integer()) :: non_neg_integer()
end
