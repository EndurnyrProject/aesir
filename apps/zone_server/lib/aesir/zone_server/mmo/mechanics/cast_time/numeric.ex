defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTime.Numeric do
  @moduledoc "Rounds an intermediate to the cast formula's binary32 width."

  @doc "Returns the binary32-rounded value as an Elixir float."
  @spec float32(number()) :: float()
  def float32(value) when is_number(value) do
    <<rounded::float-32>> = <<value * 1.0::float-32>>
    rounded
  end
end
