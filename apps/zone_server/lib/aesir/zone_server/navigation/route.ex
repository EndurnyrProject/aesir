defmodule Aesir.ZoneServer.Navigation.Route.Leg do
  @moduledoc "A positional segment of a navigation route."

  alias Aesir.ZoneServer.Navigation.PortalGraph

  @enforce_keys [:index, :map, :cells, :exit_portal, :next_map, :arrive]
  defstruct index: nil, map: nil, cells: nil, exit_portal: nil, next_map: nil, arrive: nil

  @typedoc """
  One leg of a route.

  `cells` is populated only for the leg the player is currently on; legs further
  along carry topology only. When populated, it begins at the position from which
  the leg is walked. `exit_portal` and `next_map` are `nil` on the final leg, which
  instead carries `arrive`.
  """
  @type t() :: %__MODULE__{
          index: non_neg_integer(),
          map: String.t(),
          cells: [{non_neg_integer(), non_neg_integer()}] | nil,
          exit_portal: PortalGraph.portal_id() | nil,
          next_map: String.t() | nil,
          arrive: {non_neg_integer(), non_neg_integer()} | nil
        }
end

defmodule Aesir.ZoneServer.Navigation.Route do
  @moduledoc "A positional chain of navigation legs."

  alias Aesir.ZoneServer.Navigation.Route.Leg

  @enforce_keys [:legs]
  defstruct legs: []

  @typedoc "A single leg of this route."
  @type leg :: Leg.t()

  @typedoc "An ordered chain of legs, addressed positionally rather than by map name."
  @type t() :: %__MODULE__{legs: [leg()]}

  @doc "Returns the leg at a route position."
  @spec leg_at(t(), non_neg_integer()) :: {:ok, leg()} | :error
  def leg_at(%__MODULE__{legs: legs}, index) when is_integer(index) and index >= 0,
    do: Enum.fetch(legs, index)

  @doc """
  Classifies a map arrival against the leg at the supplied route position.

  The final leg is classified like any other: it is walked to its `arrive`
  cell rather than being treated as an arrival the moment its map loads.
  """
  @spec position(t(), String.t(), non_neg_integer()) :: {:on_leg, leg()} | :off_route
  def position(%__MODULE__{} = route, map_name, index) do
    case leg_at(route, index) do
      {:ok, %Leg{map: ^map_name} = leg} -> {:on_leg, leg}
      _ -> :off_route
    end
  end
end
