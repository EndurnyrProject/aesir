defmodule Aesir.ZoneServer.Mmo.Mechanics.StatCost do
  @moduledoc """
  Contract for mode-specific status-point costs.

  Parameter caps are the same in both modes and live in `StatPoint`.
  """

  @callback cost_to_raise(non_neg_integer()) :: pos_integer()
end
