defmodule Aesir.ZoneServer.Gm.Commands.Warp do
  @moduledoc """
  `@warp <map> <x> <y>` - warps the calling GM to the given cell on another map.
  Delivery is the `{:warp, map, x, y}` cast on the caller's own session; the
  destination map/cell are validated in `WarpHandler`.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  @usage "Usage: @warp <map> <x> <y>"

  @impl true
  def name, do: "warp"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(args, _ctx) do
    with {:ok, map_name, x, y} <- parse(args) do
      GenServer.cast(self(), {:warp, map_name, x, y})
      {:ok, "Warping to #{map_name} (#{x}, #{y})"}
    end
  end

  defp parse([map_name, x_str, y_str]) do
    with {x, ""} <- Integer.parse(x_str),
         {y, ""} <- Integer.parse(y_str),
         true <- x >= 0 and y >= 0 do
      {:ok, map_name, x, y}
    else
      _ -> {:error, @usage}
    end
  end

  defp parse(_), do: {:error, @usage}
end
