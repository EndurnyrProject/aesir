defmodule Aesir.ZoneServer.Navigation.RouteSearch do
  @moduledoc """
  Map-wide A* for routes that are not unit walks: the navigation router's
  legs between portals and the player's navigation guidance. Unlike
  `Aesir.ZoneServer.Pathfinding`, it has no length window or walk refusals,
  uses a Euclidean heuristic, and never cuts the corner of a blocked cell.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Unit.MovementEngine

  @typedoc "A cell coordinate."
  @type cell :: {integer(), integer()}

  @doc """
  Finds the shortest walkable path from `start` to `goal`. Returns
  `{:ok, cells}`, the cells stepped onto in order (empty when `start` is
  `goal`), or an error when an endpoint is outside the map, the goal is not
  walkable, or no path exists.
  """
  @spec find_path(MapData.t(), cell(), cell()) :: {:ok, [cell()]} | {:error, atom()}
  def find_path(map_data, {start_x, start_y} = start, {goal_x, goal_y} = goal) do
    cond do
      not valid_position?(map_data, start_x, start_y) ->
        {:error, :invalid_start}

      not valid_position?(map_data, goal_x, goal_y) ->
        {:error, :invalid_goal}

      not Cell.traversable?(map_data.name, goal_x, goal_y) ->
        {:error, :goal_not_walkable}

      start == goal ->
        {:ok, []}

      true ->
        h = heuristic(start_x, start_y, goal_x, goal_y)
        node = %{x: start_x, y: start_y, g: 0, f: h, parent: nil}
        open_set = :gb_sets.singleton({h, start, node})
        a_star_loop(map_data, open_set, MapSet.new(), %{start => 0}, goal)
    end
  end

  defp a_star_loop(map_data, open_set, closed_set, g_scores, {goal_x, goal_y} = goal) do
    if :gb_sets.is_empty(open_set) do
      {:error, :no_path}
    else
      {{_f, pos, current}, open_set} = :gb_sets.take_smallest(open_set)

      if current.x == goal_x and current.y == goal_y do
        {:ok, reconstruct_path(current)}
      else
        closed_set = MapSet.put(closed_set, pos)
        {open_set, g_scores} = expand(map_data, open_set, g_scores, closed_set, current, goal)
        a_star_loop(map_data, open_set, closed_set, g_scores, goal)
      end
    end
  end

  defp expand(map_data, open_set, g_scores, closed_set, current, goal) do
    current.x
    |> neighbors(current.y)
    |> Enum.reduce({open_set, g_scores}, fn neighbor, acc ->
      process_neighbor(neighbor, acc, map_data, closed_set, current, goal)
    end)
  end

  defp process_neighbor({nx, ny, cost}, {open_set, g_scores}, map_data, closed_set, current, goal) do
    pos = {nx, ny}
    tentative_g = current.g + cost

    cond do
      MapSet.member?(closed_set, pos) or not valid_position?(map_data, nx, ny) ->
        {open_set, g_scores}

      not Cell.step_traversable?(map_data.name, {current.x, current.y}, pos) ->
        {open_set, g_scores}

      tentative_g >= Map.get(g_scores, pos, :infinity) ->
        {open_set, g_scores}

      true ->
        {goal_x, goal_y} = goal
        f = tentative_g + heuristic(nx, ny, goal_x, goal_y)
        node = %{x: nx, y: ny, g: tentative_g, f: f, parent: current}

        open_set =
          open_set
          |> :gb_sets.to_list()
          |> Enum.reject(fn {_f, p, _node} -> p == pos end)
          |> :gb_sets.from_list()
          |> then(&:gb_sets.add({f, pos, node}, &1))

        {open_set, Map.put(g_scores, pos, tentative_g)}
    end
  end

  defp neighbors(x, y) do
    straight = MovementEngine.straight_cost()
    diagonal = MovementEngine.diagonal_cost()

    [
      {x, y - 1, straight},
      {x + 1, y, straight},
      {x, y + 1, straight},
      {x - 1, y, straight},
      {x + 1, y - 1, diagonal},
      {x + 1, y + 1, diagonal},
      {x - 1, y + 1, diagonal},
      {x - 1, y - 1, diagonal}
    ]
  end

  defp heuristic(x1, y1, x2, y2) do
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    :math.sqrt(dx * dx + dy * dy)
  end

  defp reconstruct_path(node), do: node |> reconstruct_path([]) |> tl()

  defp reconstruct_path(nil, path), do: path
  defp reconstruct_path(node, path), do: reconstruct_path(node.parent, [{node.x, node.y} | path])

  defp valid_position?(map_data, x, y) do
    x >= 0 and x < map_data.xs and y >= 0 and y < map_data.ys
  end
end
