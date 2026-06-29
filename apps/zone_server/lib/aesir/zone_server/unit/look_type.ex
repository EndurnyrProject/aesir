defmodule Aesir.ZoneServer.Unit.LookType do
  @moduledoc """
  Constants for client look-type ids used in appearance sprite change packets.

  Values mirror the Ragnarok Online `LOOK_*` enumeration so the Rust client
  has a familiar mapping.
  """

  @look_types [
    base: 0,
    weapon: 2,
    head_bottom: 3,
    head_top: 4,
    head_mid: 5,
    shield: 8,
    robe: 12
  ]

  for {name, value} <- @look_types do
    @spec unquote(name)() :: non_neg_integer()
    def unquote(name)(), do: unquote(value)
  end
end
