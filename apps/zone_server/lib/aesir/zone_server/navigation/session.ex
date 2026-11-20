defmodule Aesir.ZoneServer.Navigation.Session do
  @moduledoc "Per-player state for an active navigation request."

  use TypedStruct

  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Target

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
  typedstruct enforce: true do
    field :ref, reference()
    field :target, Target.t()
    field :route, Route.t() | nil, default: nil
    field :leg, non_neg_integer(), default: 0
    field :flag, non_neg_integer(), default: 0
    field :hide_window, boolean(), default: false
  end
end
