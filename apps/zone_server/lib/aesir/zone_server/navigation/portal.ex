defmodule Aesir.ZoneServer.Navigation.Portal do
  @moduledoc """
  A directed warp portal with its trigger and landing cells.
  """

  @enforce_keys [:id, :map, :x, :y, :to_map, :to_x, :to_y]
  defstruct id: nil,
            map: nil,
            x: nil,
            y: nil,
            to_map: nil,
            to_x: nil,
            to_y: nil

  @type t() :: %__MODULE__{
          id: String.t(),
          map: String.t(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          to_map: String.t(),
          to_x: non_neg_integer(),
          to_y: non_neg_integer()
        }
end
