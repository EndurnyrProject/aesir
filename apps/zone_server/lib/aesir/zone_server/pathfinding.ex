defmodule Aesir.ZoneServer.Pathfinding do
  @moduledoc """
  The walk path search units use: the client's A* over a 32x32 node window,
  the straight "easy" walk, and the walk-length refusals a unit walk applies.

  The search is the one the game client runs, so a server path lands on the
  cells the client expects: a Manhattan heuristic that overestimates (10 per
  cell), straight steps costing 10 and diagonal steps 14, the client's binary
  heap and its tie order, a fixed neighbour order, and a node table indexed by
  `(x + y * 32) mod 1024`. Two different cells landing on the same table slot
  fail the search, as does a path longer than 32 steps.

  Long-range searches that are not unit walks (the navigation router) use
  `Aesir.ZoneServer.Navigation.RouteSearch` instead.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapData

  @move_cost 10
  @diagonal_cost 14
  @max_walkpath 32
  @index_mask @max_walkpath * @max_walkpath - 1
  @max_walk_path 17
  @official_walkpath 14

  @typedoc "A cell coordinate."
  @type cell :: {integer(), integer()}

  @typedoc """
  Search options. `easy: true` runs the straight walk (diagonal first, then
  straight, no corner check) instead of A*. `cells:` picks the obstacle rule:
  `:walkable` (the default, every unwalkable cell including the map's last row
  and column), `:noreach` (the same, but the last row and column are open: the
  reference's reach checks) or `:walls` (only walls, a sight-like check).
  """
  @type opts :: [easy: boolean(), cells: :walkable | :noreach | :walls]

  @doc """
  Finds the path from `start` to `goal` with the client's search. Returns
  `{:ok, cells}`, the cells stepped onto in order (empty when `start` is
  `goal`), or an error when the start or goal is outside the map, the goal is
  blocked, no path exists, or the path cannot be held in the 32-step window.
  """
  @spec find_path(MapData.t(), cell(), cell(), opts()) ::
          {:ok, [cell()]} | {:error, atom()}
  def find_path(map_data, {start_x, start_y} = start, {goal_x, goal_y} = goal, opts \\ []) do
    cond do
      not valid_position?(map_data, start_x, start_y) ->
        {:error, :invalid_start}

      not valid_position?(map_data, goal_x, goal_y) ->
        {:error, :invalid_goal}

      blocked?(map_data, goal_x, goal_y, opts) ->
        {:error, :goal_not_walkable}

      start == goal ->
        {:ok, []}

      Keyword.get(opts, :easy, false) ->
        easy_steps(map_data, start, goal, opts, [], 0)

      true ->
        a_star(map_data, start, goal, opts)
    end
  end

  @doc """
  The path for a new unit walk (players, monsters, homunculi). The client's
  search, then the walk is refused when it is longer than 17 steps, or longer
  than 14 steps while an obstacle lies on the straight line to the goal.
  """
  @spec walk_path(MapData.t(), cell(), cell(), opts()) :: {:ok, [cell()]} | {:error, atom()}
  def walk_path(map_data, start, goal, opts \\ []) do
    with {:ok, path} <- find_path(map_data, start, goal, opts),
         true <- length(path) <= @max_walk_path or {:error, :too_far} do
      official_walkpath(map_data, start, goal, path)
    end
  end

  @doc """
  The path for a walk already under way (a redirect, a blocked step, a chase
  leg): the client's search, refused only when it is longer than 14 steps
  while an obstacle lies on the straight line to the goal.
  """
  @spec rewalk_path(MapData.t(), cell(), cell(), opts()) :: {:ok, [cell()]} | {:error, atom()}
  def rewalk_path(map_data, start, goal, opts \\ []) do
    with {:ok, path} <- find_path(map_data, start, goal, opts) do
      official_walkpath(map_data, start, goal, path)
    end
  end

  defp official_walkpath(map_data, start, goal, path) do
    if length(path) <= @official_walkpath or LineOfSight.passable?(map_data.name, start, goal),
      do: {:ok, path},
      else: {:error, :too_far}
  end

  defp easy_steps(_map_data, _cell, _goal, _opts, _path, @max_walkpath), do: {:error, :no_path}

  defp easy_steps(map_data, {x, y}, {goal_x, goal_y} = goal, opts, path, steps) do
    {next_x, next_y} = next = {x + sign(goal_x - x), y + sign(goal_y - y)}

    cond do
      next == goal -> {:ok, Enum.reverse([next | path])}
      blocked?(map_data, next_x, next_y, opts) -> {:error, :no_path}
      true -> easy_steps(map_data, next, goal, opts, [next | path], steps + 1)
    end
  end

  defp sign(0), do: 0
  defp sign(delta) when delta > 0, do: 1
  defp sign(_delta), do: -1

  # The node table is a map from window slot to node; the heap is a map from
  # heap position to window slot, ordered by the node's f cost.
  defp a_star(map_data, {start_x, start_y} = start, {goal_x, goal_y} = goal, opts) do
    slot = slot(start_x, start_y)

    node = %{
      x: start_x,
      y: start_y,
      g: 0,
      f: heuristic(start_x, start_y, goal_x, goal_y),
      parent: nil,
      flag: :open
    }

    nodes = %{slot => node}
    heap = heap_push({%{}, 0}, slot, nodes)
    search(map_data, heap, nodes, start, goal, opts)
  end

  defp search(_map_data, {_positions, 0}, _nodes, _start, _goal, _opts), do: {:error, :no_path}

  defp search(map_data, heap, nodes, start, {goal_x, goal_y} = goal, opts) do
    {slot, heap} = heap_pop(heap, nodes)
    current = %{nodes[slot] | flag: :closed}
    nodes = Map.put(nodes, slot, current)

    if current.x == goal_x and current.y == goal_y do
      build_path(nodes, slot, [], 0)
    else
      case expand(map_data, heap, nodes, slot, current, goal, opts) do
        {:ok, heap, nodes} -> search(map_data, heap, nodes, start, goal, opts)
        :error -> {:error, :no_path}
      end
    end
  end

  defp build_path(_nodes, _slot, _path, len) when len > @max_walkpath, do: {:error, :no_path}

  defp build_path(nodes, slot, path, len) do
    case nodes[slot] do
      %{parent: nil} -> {:ok, path}
      %{x: x, y: y, parent: parent} -> build_path(nodes, parent, [{x, y} | path], len + 1)
    end
  end

  # Neighbours are offered in the client's order: south-east, east,
  # north-east, north, north-west, west, south-west, south (north is +y). A
  # diagonal needs both straight directions it cuts across open, and a node
  # that cannot be stored fails the whole search.
  defp expand(map_data, heap, nodes, slot, %{g: g} = current, goal, opts) do
    map_data
    |> neighbours(current, opts)
    |> Enum.reduce_while({:ok, heap, nodes}, fn {nx, ny, cost}, {:ok, heap, nodes} ->
      add_path(heap, nodes, nx, ny, g + cost, slot, goal)
    end)
  end

  defp neighbours(map_data, %{x: x, y: y}, opts) do
    open? = fn nx, ny -> not blocked?(map_data, nx, ny, opts) end
    {north?, south?, east?, west?} = straight_dirs(map_data, x, y, open?)

    candidates = [
      {south? and east?, x + 1, y - 1, @diagonal_cost},
      {east?, x + 1, y, @move_cost},
      {north? and east?, x + 1, y + 1, @diagonal_cost},
      {north?, x, y + 1, @move_cost},
      {north? and west?, x - 1, y + 1, @diagonal_cost},
      {west?, x - 1, y, @move_cost},
      {south? and west?, x - 1, y - 1, @diagonal_cost},
      {south?, x, y - 1, @move_cost}
    ]

    for {dir_open?, nx, ny, cost} <- candidates,
        dir_open? and (cost == @move_cost or open?.(nx, ny)),
        do: {nx, ny, cost}
  end

  defp straight_dirs(map_data, x, y, open?) do
    {
      y < map_data.ys - 1 and open?.(x, y + 1),
      y > 0 and open?.(x, y - 1),
      x < map_data.xs - 1 and open?.(x + 1, y),
      x > 0 and open?.(x - 1, y)
    }
  end

  defp add_path(heap, nodes, x, y, g, parent, {goal_x, goal_y}) do
    slot = slot(x, y)
    f = g + heuristic(x, y, goal_x, goal_y)

    case nodes[slot] do
      %{x: ^x, y: ^y, g: old_g} = node when g < old_g ->
        improve_node(heap, nodes, slot, %{node | g: g, parent: parent, f: f})

      %{x: ^x, y: ^y} ->
        {:cont, {:ok, heap, nodes}}

      nil when x == 0 and y == 0 ->
        {:cont, {:ok, heap, nodes}}

      %{x: ox, y: oy} when ox != 0 or oy != 0 ->
        {:halt, :error}

      _free ->
        node = %{x: x, y: y, g: g, f: f, parent: parent, flag: :open}
        nodes = Map.put(nodes, slot, node)
        {:cont, {:ok, heap_push(heap, slot, nodes), nodes}}
    end
  end

  # A cheaper way to a known node: a closed node is pushed again, an open one
  # is moved to its new place in the heap.
  defp improve_node(heap, nodes, slot, %{flag: :closed} = node) do
    nodes = Map.put(nodes, slot, node)
    {:cont, {:ok, heap_push(heap, slot, nodes), Map.put(nodes, slot, %{node | flag: :open})}}
  end

  defp improve_node(heap, nodes, slot, %{flag: :open} = node) do
    nodes = Map.put(nodes, slot, node)

    case heap_update(heap, slot, nodes) do
      {:ok, heap} -> {:cont, {:ok, heap, nodes}}
      :error -> {:halt, :error}
    end
  end

  defp slot(x, y), do: Bitwise.band(x + y * @max_walkpath, @index_mask)

  defp heuristic(x0, y0, x1, y1), do: @move_cost * (abs(x1 - x0) + abs(y1 - y0))

  # The client's binary heap: a push appends and bubbles toward the root while
  # the parent costs strictly more; a pop moves the last entry to the root,
  # sinks it to a leaf along the cheaper child, then bubbles it back up; an
  # update bubbles the entry up, then sinks whatever sits at its old position.
  defp heap_push({positions, size}, slot, nodes),
    do: {bubble_up(Map.put(positions, size, slot), 0, size, nodes), size + 1}

  defp heap_pop({positions, size}, nodes) do
    top = positions[0]
    {last, positions} = Map.pop(positions, size - 1)
    size = size - 1

    if size == 0,
      do: {top, {positions, 0}},
      else: {top, {sink(Map.put(positions, 0, last), 0, size, nodes), size}}
  end

  defp heap_update({positions, size}, slot, nodes) do
    case Enum.find(0..(size - 1)//1, &(positions[&1] == slot)) do
      nil ->
        :error

      index ->
        positions = positions |> bubble_up(0, index, nodes) |> sink(index, size, nodes)
        {:ok, {positions, size}}
    end
  end

  defp bubble_up(positions, start, index, nodes) when index > start do
    parent = div(index - 1, 2)

    if cost(positions, parent, nodes) <= cost(positions, index, nodes),
      do: positions,
      else: positions |> swap(parent, index) |> bubble_up(start, parent, nodes)
  end

  defp bubble_up(positions, _start, _index, _nodes), do: positions

  defp sink(positions, index, size, nodes) do
    {positions, leaf} = sink_to_leaf(positions, index, size, nodes)
    bubble_up(positions, index, leaf, nodes)
  end

  defp sink_to_leaf(positions, index, size, nodes) do
    left = index * 2 + 1
    right = index * 2 + 2

    cond do
      left >= size ->
        {positions, index}

      right >= size or cost(positions, left, nodes) < cost(positions, right, nodes) ->
        positions |> swap(index, left) |> sink_to_leaf(left, size, nodes)

      true ->
        positions |> swap(index, right) |> sink_to_leaf(right, size, nodes)
    end
  end

  defp cost(positions, index, nodes), do: nodes[positions[index]].f

  defp swap(positions, i, j), do: %{positions | i => positions[j], j => positions[i]}

  defp valid_position?(map_data, x, y) do
    x >= 0 and x < map_data.xs and y >= 0 and y < map_data.ys
  end

  defp blocked?(map_data, x, y, opts) do
    case Keyword.get(opts, :cells, :walkable) do
      :walls -> MapData.check_cell(map_data, x, y, :chk_wall)
      :walkable -> not Cell.traversable?(map_data.name, x, y)
      :noreach -> not MapData.edge?(map_data, x, y) and not Cell.traversable?(map_data.name, x, y)
    end
  end

  @doc """
  Simplifies a path by removing intermediate points in straight lines.
  This reduces the number of position updates sent to clients.
  """
  @spec simplify_path([cell()]) :: [cell()]
  def simplify_path(path) when length(path) <= 2, do: path

  def simplify_path(path) do
    result =
      path
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.reduce([hd(path)], fn
        [{x1, y1}, {x2, y2}, {x3, y3}], acc ->
          if on_line?(x1, y1, x2, y2, x3, y3) do
            acc
          else
            acc ++ [{x2, y2}]
          end
      end)

    if List.last(result) != List.last(path) do
      result ++ [List.last(path)]
    else
      result
    end
  end

  @doc "Simplifies only paths whose cells remain traversable on effective terrain."
  @spec simplify_path([cell()], String.t()) :: [cell()]
  def simplify_path(path, map_name) do
    if Enum.all?(path, fn {x, y} -> Cell.traversable?(map_name, x, y) end) do
      simplify_path(path)
    else
      path
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
