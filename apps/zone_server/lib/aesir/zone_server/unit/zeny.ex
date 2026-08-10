defmodule Aesir.ZoneServer.Unit.Zeny do
  @moduledoc """
  Zeny balance policy.
  """

  @doc """
  Returns the maximum zeny balance.
  """
  @spec max_zeny() :: pos_integer()
  def max_zeny, do: 1_000_000_000
end
