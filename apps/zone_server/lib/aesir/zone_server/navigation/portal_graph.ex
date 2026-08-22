defmodule Aesir.ZoneServer.Navigation.PortalGraph.Edge do
  @moduledoc "A directed navigation graph edge with a non-negative pathfinder cost."

  @enforce_keys [:kind, :to, :cost]
  defstruct kind: nil, to: nil, cost: nil

  @type t() :: %__MODULE__{
          kind: :warp | :walk,
          to: String.t(),
          cost: float()
        }
end

defmodule Aesir.ZoneServer.Navigation.PortalGraph do
  @moduledoc """
  Lazily loaded directed graph of static warp portals and intra-map walking costs.

  A portal node is the post-warp state: reaching portal B means the route has
  walked to B's trigger and crossed it. A walk edge from A to B therefore costs
  the immutable-terrain path from A's landing to B's trigger; runtime terrain is
  considered later when the current leg is materialized.
  """

  alias Aesir.ZoneServer.Navigation.Portal
  alias Aesir.ZoneServer.Navigation.PortalGraph.Builder
  alias Aesir.ZoneServer.Navigation.PortalGraph.Edge

  @pt_key __MODULE__

  @typedoc "A unique warp portal identifier."
  @type portal_id :: String.t()

  @typedoc "The immutable portal graph indexes."
  @type t :: %{
          portals: %{optional(portal_id()) => Portal.t()},
          exits_by_map: %{optional(String.t()) => [Portal.t()]},
          landings_by_map: %{optional(String.t()) => [Portal.t()]},
          edges: %{optional(portal_id()) => [Edge.t()]}
        }

  @doc "Returns portals whose trigger sits on `map_name`."
  @spec exits_on(String.t()) :: [Portal.t()]
  def exits_on(map_name), do: Map.get(graph().exits_by_map, map_name, [])

  @doc "Returns portals whose landing sits on `map_name`."
  @spec landings_on(String.t()) :: [Portal.t()]
  def landings_on(map_name), do: Map.get(graph().landings_by_map, map_name, [])

  @doc "Returns outgoing navigation edges from a portal's post-warp state."
  @spec edges_from(portal_id()) :: [Edge.t()]
  def edges_from(portal_id), do: Map.get(graph().edges, portal_id, [])

  @doc "Fetches a portal by its unique warp id."
  @spec fetch(portal_id()) :: {:ok, Portal.t()} | :error
  def fetch(portal_id), do: Map.fetch(graph().portals, portal_id)

  @doc "Reloads the graph from its disk cache or current source data."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, Builder.load())
    :ok
  end

  @spec graph() :: t()
  defp graph do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = Builder.load()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end
end
