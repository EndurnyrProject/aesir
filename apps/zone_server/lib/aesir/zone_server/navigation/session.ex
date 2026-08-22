defmodule Aesir.ZoneServer.Navigation.Session do
  @moduledoc "Per-player state for an active navigation request."

  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Target

  @enforce_keys [:ref, :target]
  defstruct ref: nil, target: nil, route: nil, leg: 0

  @typedoc """
  An active navigation, owned by the player's session.

  `ref` is the epoch token: a routing result carrying a stale `ref` is discarded
  rather than applied, so a slow solve cannot overwrite a fresher route.
  `target` is retained alongside `route` because re-routing after an off-route
  arrival needs the original intent - the route is the part that went stale.
  `route` is `nil` while the first solve is still in flight.
  """
  @type t() :: %__MODULE__{
          ref: reference(),
          target: Target.t(),
          route: Route.t() | nil,
          leg: non_neg_integer()
        }
end
