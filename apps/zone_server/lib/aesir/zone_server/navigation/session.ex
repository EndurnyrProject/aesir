defmodule Aesir.ZoneServer.Navigation.Session do
  @moduledoc "Per-player state for an active navigation request."

  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Target

  @enforce_keys [:ref, :target]
  defstruct ref: nil, target: nil, route: nil, leg: 0, flag: 0, hide_window: false

  @typedoc """
  An active navigation, owned by the player's session.

  `ref` is the epoch token: a routing result carrying a stale `ref` is discarded
  rather than applied, so a slow solve cannot overwrite a fresher route.
  `target` is retained alongside `route` because re-routing after an off-route
  arrival needs the original intent - the route is the part that went stale.
  `route` is `nil` while the first solve is still in flight. `flag` and
  `hide_window` outlive the inbound request or script call so asynchronous route
  completion and subsequent legs retain the producer's display options.
  """
  @type t() :: %__MODULE__{
          ref: reference(),
          target: Target.t(),
          route: Route.t() | nil,
          leg: non_neg_integer(),
          flag: non_neg_integer(),
          hide_window: boolean()
        }
end
