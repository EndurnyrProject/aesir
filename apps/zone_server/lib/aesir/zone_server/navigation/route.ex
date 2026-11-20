defmodule Aesir.ZoneServer.Navigation.Route.Leg do
  @moduledoc "A positional segment of a navigation route."

  use TypedStruct

  alias Aesir.ZoneServer.Navigation.PortalGraph

  @typedoc """
  One leg of a route.

  `cells` is populated only for the leg the player is currently on; legs further
  along carry topology only. When populated, it begins at the position from which
  the leg is walked. `exit_portal` and `next_map` are `nil` on the final leg, which
  instead carries `arrive`.
  """
  typedstruct enforce: true do
    field :index, non_neg_integer()
    field :map, String.t()
    field :cells, [cell()] | nil
    field :exit_portal, PortalGraph.portal_id() | nil
    field :next_map, String.t() | nil
    field :arrive, cell() | nil
  end

  @typedoc "A cell coordinate within a route's map."
  @type cell :: {non_neg_integer(), non_neg_integer()}
end

defmodule Aesir.ZoneServer.Navigation.Route do
  @moduledoc "A positional chain of navigation legs."

  use TypedStruct

  alias Aesir.ZoneServer.Navigation.Route.Leg

  @typedoc "A single leg of this route."
  @type leg :: Leg.t()

  @typedoc "An ordered chain of legs, addressed positionally rather than by map name."
  typedstruct do
    field :legs, [leg()], default: [], enforce: true
  end

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
