defmodule Aesir.ZoneServer.Navigation.Portal do
  @moduledoc """
  A directed warp portal with its trigger and landing cells.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Navigation.PortalGraph

  @typedoc "A portal's identity, trigger cell, and landing cell."
  typedstruct enforce: true do
    field :id, PortalGraph.portal_id()
    field :map, String.t()
    field :x, non_neg_integer()
    field :y, non_neg_integer()
    field :to_map, String.t()
    field :to_x, non_neg_integer()
    field :to_y, non_neg_integer()
  end
end
