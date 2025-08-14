defmodule Aesir.ZoneServer.Pathfinding do
  @moduledoc """
  A* pathfinding implementation for character movement in the zone server.
  Handles path calculation considering map obstacles from GAT data.
  """

  alias Aesir.ZoneServer.Map.MapData

  # √2 for diagonal movement
  @diagonal_cost 1.414
  # Cost for straight movement
  @straight_cost 1.0

  defmodule Node do
    @moduledoc false
    defstruct [:x, :y, :g_score, :h_score, :f_score, :parent]

    def new(x, y, g_score \\ 0, h_score \\ 0, parent \\ nil) do
      %__MODULE__{
        x: x,
        y: y,
        g_score: g_score,
        h_score: h_score,
        f_score: g_score + h_score,
        parent: parent
      }
    end
  end

  @doc """
  Finds the shortest path from start to goal using A* algorithm.
  Returns {:ok, path} where path is a list of {x, y} coordinates,
  or {:error, :no_path} if no valid path exists.
  """
  def find_path(map_data, {start_x, start_y}, {goal_x, goal_y}) do
    cond do
      not valid_position?(map_data, start_x, start_y) ->
        {:error, :invalid_start}

      not valid_position?(map_data, goal_x, goal_y) ->
        {:error, :invalid_goal}

      not walkable?(map_data, goal_x, goal_y) ->
        {:error, :goal_not_walkable}

      start_x == goal_x and start_y == goal_y ->
        {:ok, []}

      true ->
        start_node = Node.new(start_x, start_y, 0, heuristic(start_x, start_y, goal_x, goal_y))

        open_set = :gb_sets.singleton({start_node.f_score, {start_x, start_y}, start_node})
        closed_set = MapSet.new()
        g_scores = %{{start_x, start_y} => 0}

        a_star_loop(map_data, open_set, closed_set, g_scores, {goal_x, goal_y})
    end
  end

  defp a_star_loop(map_data, open_set, closed_set, g_scores, {goal_x, goal_y} = goal) do
    if :gb_sets.is_empty(open_set) do
      {:error, :no_path}
    else
      {{_f_score, pos, current}, open_set} = :gb_sets.take_smallest(open_set)

      if current.x == goal_x and current.y == goal_y do
        {:ok, reconstruct_path(current)}
      else
        closed_set = MapSet.put(closed_set, pos)

        {open_set, g_scores} =
          get_neighbors(current.x, current.y)
          |> Enum.reduce({open_set, g_scores}, fn {nx, ny, move_cost}, {open_acc, g_acc} ->
            neighbor_pos = {nx, ny}

            if MapSet.member?(closed_set, neighbor_pos) or
                 not valid_position?(map_data, nx, ny) or
                 not walkable?(map_data, nx, ny) do
              {open_acc, g_acc}
            else
              tentative_g = current.g_score + move_cost
              current_g = Map.get(g_acc, neighbor_pos, :infinity)

              if tentative_g < current_g do
                h_score = heuristic(nx, ny, goal_x, goal_y)
                neighbor = Node.new(nx, ny, tentative_g, h_score, current)

                open_acc = remove_from_open_set(open_acc, neighbor_pos)

                open_acc = :gb_sets.add({neighbor.f_score, neighbor_pos, neighbor}, open_acc)
                g_acc = Map.put(g_acc, neighbor_pos, tentative_g)

                {open_acc, g_acc}
              else
                {open_acc, g_acc}
              end
            end
          end)

        a_star_loop(map_data, open_set, closed_set, g_scores, goal)
      end
    end
  end

  defp remove_from_open_set(open_set, pos) do
    :gb_sets.to_list(open_set)
    |> Enum.reject(fn {_f, p, _node} -> p == pos end)
    |> :gb_sets.from_list()
  end

  defp get_neighbors(x, y) do
    [
      # North
      {x, y - 1, @straight_cost},
      # East
      {x + 1, y, @straight_cost},
      # South
      {x, y + 1, @straight_cost},
      # West
      {x - 1, y, @straight_cost},
      # Diagonal moves (cost √2)
      # Northeast
      {x + 1, y - 1, @diagonal_cost},
      # Southeast
      {x + 1, y + 1, @diagonal_cost},
      # Southwest
      {x - 1, y + 1, @diagonal_cost},
      # Northwest
      {x - 1, y - 1, @diagonal_cost}
    ]
  end

  defp heuristic(x1, y1, x2, y2) do
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    :math.sqrt(dx * dx + dy * dy)
  end

  defp reconstruct_path(node) do
    node
    |> reconstruct_path([])
    |> tl()
  end

  defp reconstruct_path(nil, path), do: path

  defp reconstruct_path(node, path) do
    reconstruct_path(node.parent, [{node.x, node.y} | path])
  end

  defp valid_position?(map_data, x, y) do
    x >= 0 and x < map_data.xs and y >= 0 and y < map_data.ys
  end

  defp walkable?(map_data, x, y) do
    MapData.is_walkable?(map_data, x, y)
  end

  @doc """
  Simplifies a path by removing intermediate points in straight lines.
  This reduces the number of position updates sent to clients.
  """
  def simplify_path(path) when length(path) <= 2, do: path

  def simplify_path(path) do
    result =
      path
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.reduce([hd(path)], fn
        [{x1, y1}, {x2, y2}, {x3, y3}], acc ->
          # Check if middle point is on the line between first and last
          if on_line?(x1, y1, x2, y2, x3, y3) do
            acc
          else
            # Keep middle point (append to maintain order)
            acc ++ [{x2, y2}]
          end
      end)

    # Add the last point if not already included
    if List.last(result) != List.last(path) do
      result ++ [List.last(path)]
    else
      result
    end
  end

  defp on_line?(x1, y1, x2, y2, x3, y3) do
    dx1 = x2 - x1
    dy1 = y2 - y1
    dx2 = x3 - x2
    dy2 = y3 - y2

    dx1 * dy2 == dy1 * dx2
  end
end

