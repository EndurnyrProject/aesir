defmodule Aesir.ZoneServer.Navigation.PortalGraph.Builder do
  @moduledoc """
  Builds and disk-caches the directed portal graph.

  A node is the state after its portal has been crossed. Walk edges start at
  that portal's landing, reach another portal's trigger, and include crossing
  the destination portal by arriving at its post-warp node.

  Walk costs use immutable `MapData` terrain. Runtime contributions such as Ice
  Wall affect the live path for the current leg, never the long-lived topology.

  Cache freshness uses SHA-256 fingerprints of the active warp and static
  exclusion sources plus `maps.mcache`. Unlike data caches where a stale value
  is tolerable briefly, stale navigation data can route players through a map
  an operator just hid, so POSIX-second mtimes are not sufficient here.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.Flood
  alias Aesir.ZoneServer.Navigation.Portal
  alias Aesir.ZoneServer.Navigation.PortalGraph.Edge
  alias Aesir.ZoneServer.Npc.Warp
  alias Aesir.ZoneServer.Npc.Warps

  @cache_file "portal_graph.etf"
  @fallback_radius 5

  @doc "Loads a fresh cached graph or rebuilds it from the current world data."
  @spec load(keyword()) :: Aesir.ZoneServer.Navigation.PortalGraph.t()
  def load(opts \\ []) do
    warp_sources = Source.sources("warps")
    map_cache_path = Keyword.get(opts, :map_cache_path, default_map_cache_path())
    inputs = warp_sources ++ Exclusions.sources() ++ [map_cache_path]
    fingerprint = fingerprint(inputs)
    cache = Path.join([Source.base_dir("warps"), ".cache", @cache_file])

    with {:ok, binary} <- File.read(cache),
         {:ok, %{inputs: ^inputs, fingerprint: ^fingerprint, graph: graph}} <-
           decode_cache(binary) do
      graph
    else
      _ ->
        graph = build()
        write_cache!(cache, %{inputs: inputs, fingerprint: fingerprint, graph: graph})
        graph
    end
  end

  @spec build() :: Aesir.ZoneServer.Navigation.PortalGraph.t()
  defp build do
    portals =
      Warps.all()
      |> Map.values()
      |> List.flatten()
      |> Enum.reject(&excluded?/1)
      |> Enum.map(&to_portal/1)
      |> Enum.sort_by(& &1.id)

    exits_by_map = Enum.group_by(portals, & &1.map)
    landings_by_map = Enum.group_by(portals, & &1.to_map)

    walk_edges = build_walk_edges(landings_by_map, exits_by_map)

    edges = Map.new(portals, &{&1.id, Map.get(walk_edges, &1.id, [])})

    %{
      portals: Map.new(portals, &{&1.id, &1}),
      exits_by_map: exits_by_map,
      landings_by_map: landings_by_map,
      edges: edges
    }
  end

  @spec build_walk_edges(%{String.t() => [Portal.t()]}, %{String.t() => [Portal.t()]}) ::
          %{String.t() => [Edge.t()]}
  defp build_walk_edges(landings_by_map, exits_by_map) do
    landings_by_map
    |> Enum.filter(fn {map_name, _landings} -> Map.has_key?(exits_by_map, map_name) end)
    |> Task.async_stream(
      fn {map_name, landings} ->
        {map_name, walk_edges(map_name, landings, Map.fetch!(exits_by_map, map_name))}
      end,
      max_concurrency: System.schedulers_online() * 2,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.flat_map(fn
      {:ok, {_map_name, edges}} -> edges
      {:exit, reason} -> exit(reason)
    end)
    |> Map.new()
  end

  @spec walk_edges(String.t(), [Portal.t()], [Portal.t()]) ::
          [{String.t(), [Edge.t()]}]
  defp walk_edges(map_name, landings, exits) do
    map_data = MapCache.get!(map_name)
    targets = MapSet.new(exits, &{&1.x, &1.y})

    Enum.map(landings, fn landing ->
      start = nearest_walkable(map_data, {landing.to_x, landing.to_y})
      costs = Flood.costs(map_data, start, targets, terrain: :static)

      edges = exits |> Enum.flat_map(&walk_edge(&1, costs)) |> Enum.sort_by(& &1.to)

      {landing.id, edges}
    end)
  end

  @spec walk_edge(Portal.t(), %{Flood.cell() => Flood.cost()}) :: [Edge.t()]
  defp walk_edge(portal, costs) do
    case Map.fetch(costs, {portal.x, portal.y}) do
      {:ok, cost} -> [%Edge{kind: :walk, to: portal.id, cost: cost}]
      :error -> []
    end
  end

  @spec nearest_walkable(MapData.t(), {integer(), integer()}) :: {integer(), integer()}
  defp nearest_walkable(map_data, {x, y} = cell) do
    if MapData.walkable?(map_data, x, y) do
      cell
    else
      Enum.find_value(1..@fallback_radius, cell, fn radius ->
        Enum.find(ring_cells(x, y, radius), &walkable?(map_data, &1))
      end)
    end
  end

  @spec walkable?(MapData.t(), {integer(), integer()}) :: boolean()
  defp walkable?(map_data, {x, y}), do: MapData.walkable?(map_data, x, y)

  @spec ring_cells(integer(), integer(), pos_integer()) :: [{integer(), integer()}]
  defp ring_cells(x, y, radius) do
    for dy <- -radius..radius,
        dx <- -radius..radius,
        max(abs(dx), abs(dy)) == radius do
      {x + dx, y + dy}
    end
  end

  @spec excluded?(Warp.t()) :: boolean()
  defp excluded?(%Warp{map: map, to_map: to_map}) do
    Exclusions.statically_excluded?(map) or Exclusions.statically_excluded?(to_map)
  end

  @spec to_portal(Warp.t()) :: Portal.t()
  defp to_portal(%Warp{} = warp) do
    %Portal{
      id: warp.id,
      map: warp.map,
      x: warp.x,
      y: warp.y,
      to_map: warp.to_map,
      to_x: warp.to_x,
      to_y: warp.to_y
    }
  end

  @spec default_map_cache_path() :: Path.t()
  defp default_map_cache_path, do: Path.join(:code.priv_dir(:zone_server), "maps.mcache")

  @spec fingerprint([Path.t()]) :: [binary()]
  defp fingerprint(paths) do
    Enum.map(paths, fn path -> :crypto.hash(:sha256, File.read!(path)) end)
  end

  @spec decode_cache(binary()) :: {:ok, term()} | :error
  defp decode_cache(binary) do
    {:ok, :erlang.binary_to_term(binary)}
  rescue
    ArgumentError -> :error
  end

  @spec write_cache!(Path.t(), term()) :: :ok
  defp write_cache!(cache, blob) do
    File.mkdir_p!(Path.dirname(cache))
    File.write!(cache, :erlang.term_to_binary(blob))
  end
end
