defmodule Aesir.ZoneServer.Navigation.Router do
  @moduledoc """
  Computes the cheapest route from a map cell to a set of navigation candidates.

  Current-map paths use live terrain. Cross-map topology comes from the immutable
  portal graph and is filtered by the runtime exclusion set once per request.
  """

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.Flood
  alias Aesir.ZoneServer.Navigation.Portal
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.PortalGraph.Edge
  alias Aesir.ZoneServer.Navigation.Route
  alias Aesir.ZoneServer.Navigation.Route.Leg
  alias Aesir.ZoneServer.Navigation.Target
  alias Aesir.ZoneServer.Pathfinding

  @typedoc "A map name and cell coordinate."
  @type origin :: {String.t(), non_neg_integer(), non_neg_integer()}

  @doc "Returns the lowest estimated-travel-time route to any reachable candidate."
  @spec route(origin(), [Target.candidate(), ...], keyword()) ::
          {:ok, Route.t()} | {:error, :unreachable}
  def route({origin_map, x, y}, candidates, opts) do
    walk_speed = walk_speed!(opts)
    excluded = Exclusions.runtime_excluded()
    origin_cell = {x, y}
    map_data = MapCache.get!(origin_map)

    direct_routes =
      direct_routes(map_data, origin_cell, origin_map, candidates, excluded, walk_speed)

    seeds = portal_seeds(map_data, origin_cell, origin_map, excluded, walk_speed)
    portal_routes = portal_routes(seeds, candidates, excluded, walk_speed, origin_map)

    case direct_routes ++ portal_routes do
      [] -> {:error, :unreachable}
      routes -> {:ok, routes |> Enum.min_by(& &1.cost) |> Map.fetch!(:route)}
    end
  end

  defp direct_routes(map_data, origin, origin_map, candidates, excluded, walk_speed) do
    candidates
    |> Enum.filter(fn {map_name, _destination} ->
      map_name == origin_map and not MapSet.member?(excluded, map_name)
    end)
    |> Enum.flat_map(fn
      {^origin_map, :any} ->
        [route_option(0.0, direct_route(origin_map, [], origin))]

      {^origin_map, destination} ->
        case Pathfinding.find_path(map_data, origin, destination, []) do
          {:ok, path} ->
            cost = travel_time(Flood.path_cost(origin, path), walk_speed)
            [route_option(cost, direct_route(origin_map, path, destination))]

          {:error, _reason} ->
            []
        end
    end)
  end

  defp portal_seeds(map_data, origin, origin_map, excluded, walk_speed) do
    origin_map
    |> PortalGraph.exits_on()
    |> Enum.reject(&MapSet.member?(excluded, &1.to_map))
    |> Enum.flat_map(fn portal ->
      case Pathfinding.find_path(map_data, origin, {portal.x, portal.y}, []) do
        {:ok, path} ->
          cost = travel_time(Flood.path_cost(origin, path), walk_speed)
          [%{portal_id: portal.id, cost: cost, path: path}]

        {:error, _reason} ->
          []
      end
    end)
  end

  defp portal_routes([], _candidates, _excluded, _walk_speed, _origin_map), do: []

  defp portal_routes(seeds, candidates, excluded, walk_speed, origin_map) do
    {distances, previous, seed_paths} = dijkstra(seeds, excluded, walk_speed)

    candidates
    |> Enum.reject(fn {map_name, _destination} -> MapSet.member?(excluded, map_name) end)
    |> Enum.flat_map(fn {map_name, destination} ->
      map_name
      |> PortalGraph.landings_on()
      |> Enum.flat_map(fn portal ->
        terminal_route(
          portal,
          destination,
          distances,
          previous,
          seed_paths,
          walk_speed,
          origin_map
        )
      end)
    end)
  end

  defp dijkstra(seeds, excluded, walk_speed) do
    {queue, distances, previous, seed_paths} =
      Enum.reduce(seeds, {:gb_sets.empty(), %{}, %{}, %{}}, fn seed,
                                                               {queue, distances, previous,
                                                                seed_paths} ->
        {
          :gb_sets.add({seed.cost, seed.portal_id}, queue),
          Map.put(distances, seed.portal_id, seed.cost),
          Map.put(previous, seed.portal_id, nil),
          Map.put(seed_paths, seed.portal_id, seed.path)
        }
      end)

    dijkstra(queue, distances, previous, seed_paths, excluded, walk_speed)
  end

  defp dijkstra(queue, distances, previous, seed_paths, excluded, walk_speed) do
    if :gb_sets.is_empty(queue) do
      {distances, previous, seed_paths}
    else
      {entry, queue} = :gb_sets.take_smallest(queue)
      visit(entry, queue, distances, previous, seed_paths, excluded, walk_speed)
    end
  end

  defp visit({cost, portal_id}, queue, distances, previous, seed_paths, excluded, walk_speed) do
    if cost > Map.fetch!(distances, portal_id) do
      dijkstra(queue, distances, previous, seed_paths, excluded, walk_speed)
    else
      {queue, distances, previous} =
        portal_id
        |> PortalGraph.edges_from()
        |> Enum.reduce({queue, distances, previous}, fn edge, state ->
          relax(edge, portal_id, cost, state, excluded, walk_speed)
        end)

      dijkstra(queue, distances, previous, seed_paths, excluded, walk_speed)
    end
  end

  defp relax(%Edge{to: next_id, cost: distance}, portal_id, cost, state, excluded, walk_speed) do
    {queue, distances, previous} = state
    {:ok, next_portal} = PortalGraph.fetch(next_id)
    next_cost = cost + travel_time(distance, walk_speed)

    if not MapSet.member?(excluded, next_portal.to_map) and
         next_cost < Map.get(distances, next_id, :infinity) do
      {
        :gb_sets.add({next_cost, next_id}, queue),
        Map.put(distances, next_id, next_cost),
        Map.put(previous, next_id, portal_id)
      }
    else
      state
    end
  end

  defp terminal_route(
         portal,
         destination,
         distances,
         previous,
         seed_paths,
         walk_speed,
         origin_map
       ) do
    case Map.fetch(distances, portal.id) do
      {:ok, portal_cost} ->
        reachable_terminal_route(
          portal,
          destination,
          portal_cost,
          previous,
          seed_paths,
          walk_speed,
          origin_map
        )

      :error ->
        []
    end
  end

  defp reachable_terminal_route(
         portal,
         destination,
         portal_cost,
         previous,
         seed_paths,
         walk_speed,
         origin_map
       ) do
    case terminal_cost(portal, destination, walk_speed) do
      {:ok, terminal_cost, arrive} ->
        portal_ids = portal_chain(portal.id, previous)
        route = materialize_route(portal_ids, seed_paths, origin_map, portal.to_map, arrive)
        [route_option(portal_cost + terminal_cost, route)]

      {:error, _reason} ->
        []
    end
  end

  defp terminal_cost(%Portal{to_x: x, to_y: y}, :any, _walk_speed), do: {:ok, 0.0, {x, y}}

  defp terminal_cost(%Portal{to_map: map_name, to_x: x, to_y: y}, destination, walk_speed) do
    start = {x, y}

    case Pathfinding.find_path(MapCache.get!(map_name), start, destination, []) do
      {:ok, path} -> {:ok, travel_time(Flood.path_cost(start, path), walk_speed), destination}
      {:error, reason} -> {:error, reason}
    end
  end

  defp portal_chain(portal_id, previous), do: portal_chain(portal_id, previous, [])

  defp portal_chain(portal_id, previous, chain) do
    case Map.fetch!(previous, portal_id) do
      nil -> [portal_id | chain]
      prior_id -> portal_chain(prior_id, previous, [portal_id | chain])
    end
  end

  defp materialize_route(portal_ids, seed_paths, origin_map, destination_map, arrive) do
    [first_id | _rest] = portal_ids

    portal_legs =
      portal_ids
      |> Enum.with_index()
      |> Enum.map(fn {portal_id, index} ->
        {:ok, portal} = PortalGraph.fetch(portal_id)

        %Leg{
          index: index,
          map: if(index == 0, do: origin_map, else: portal.map),
          cells: if(index == 0, do: Map.fetch!(seed_paths, first_id), else: nil),
          exit_portal: portal.id,
          next_map: portal.to_map,
          arrive: nil
        }
      end)

    final_leg = %Leg{
      index: length(portal_ids),
      map: destination_map,
      cells: nil,
      exit_portal: nil,
      next_map: nil,
      arrive: arrive
    }

    %Route{legs: portal_legs ++ [final_leg]}
  end

  defp direct_route(map_name, path, arrive) do
    %Route{
      legs: [
        %Leg{
          index: 0,
          map: map_name,
          cells: path,
          exit_portal: nil,
          next_map: nil,
          arrive: arrive
        }
      ]
    }
  end

  defp route_option(cost, route), do: %{cost: cost, route: route}
  defp travel_time(distance, walk_speed), do: distance / walk_speed

  defp walk_speed!(opts) do
    case Keyword.fetch!(opts, :walk_speed) do
      walk_speed when is_number(walk_speed) and walk_speed > 0 ->
        walk_speed

      walk_speed ->
        raise ArgumentError, "walk_speed must be positive, got: #{inspect(walk_speed)}"
    end
  end
end
