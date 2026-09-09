defmodule Aesir.ZoneServer.Mmo.Size do
  @moduledoc """
  Shared unit size categories, independent of weapon-size damage formulas.
  """

  @typedoc "A unit's size category."
  @type t :: :small | :medium | :large
end
