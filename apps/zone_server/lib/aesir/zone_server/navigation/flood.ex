defmodule Aesir.ZoneServer.Navigation.Flood do
  @moduledoc """
  Computes exact walking costs from one map cell to a set of target cells.

  Straight and diagonal steps use `Unit.MovementEngine` costs. Traversability
  defaults to the runtime-aware `Map.Cell.step_traversable?/4`; callers building
  long-lived topology can select immutable base terrain instead.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Unit.MovementEngine

  @typedoc "A map cell coordinate pair."
  @type cell :: {integer(), integer()}

  @typedoc "A walking cost in pathfinder distance units."
  @type cost :: float()

  @typedoc "The terrain view used to decide whether a step is traversable."
  @type terrain :: :runtime | :static

  @doc "Returns the cost to each reachable target cell in one weighted flood."
  @spec costs(MapData.t(), cell(), MapSet.t(cell()), terrain: terrain()) :: %{
          optional(cell()) => cost()
        }
  def costs(%MapData{} = map_data, start, targets, opts \\ []) do
    terrain = Keyword.get(opts, :terrain, :runtime)

    flood(
      map_data,
      :gb_sets.singleton({0.0, start}),
      %{start => 0.0},
      MapSet.new(),
      targets,
      %{},
      terrain
    )
  end

  @doc """
  Sums movement costs for walking `path` starting from `start`.

  Takes the origin separately because `Pathfinding.find_path/4` returns the
  path *without* its starting cell. Costing that list on its own would silently
  drop the first step - worth `1.0` or `1.414` - so the origin is a required
  argument rather than a caller's responsibility to remember.
  """
  @spec path_cost(cell(), [cell()]) :: cost()
  def path_cost(start, path) do
    [start | path]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(0.0, fn [from, to], cost ->
      cost + MovementEngine.get_movement_cost(from, to)
    end)
  end

  defp flood(map_data, queue, distances, visited, targets, costs, terrain) do
    if MapSet.size(targets) == 0 or :gb_sets.is_empty(queue) do
      costs
    else
      expand(map_data, queue, distances, visited, targets, costs, terrain)
    end
  end

  defp expand(map_data, queue, distances, visited, targets, costs, terrain) do
    {{cost, cell}, queue} = :gb_sets.take_smallest(queue)

    if MapSet.member?(visited, cell) do
      flood(map_data, queue, distances, visited, targets, costs, terrain)
    else
      expand_cell(map_data, queue, distances, visited, targets, costs, {cell, cost}, terrain)
    end
  end

  defp expand_cell(map_data, queue, distances, visited, targets, costs, {cell, cost}, terrain) do
    visited = MapSet.put(visited, cell)
    {targets, costs} = collect_target(cell, cost, targets, costs)

    {queue, distances} =
      cell
      |> neighbors()
      |> Enum.reduce({queue, distances}, fn {neighbor, step_cost}, state ->
        relax(map_data, cell, neighbor, step_cost, visited, state, terrain)
      end)

    flood(map_data, queue, distances, visited, targets, costs, terrain)
  end

  defp collect_target(cell, cost, targets, costs) do
    if MapSet.member?(targets, cell) do
      {MapSet.delete(targets, cell), Map.put(costs, cell, cost)}
    else
      {targets, costs}
    end
  end

  defp relax(map_data, from, to, step_cost, visited, {queue, distances}, terrain) do
    new_cost = Map.fetch!(distances, from) + step_cost

    if valid_position?(map_data, to) and not MapSet.member?(visited, to) and
         step_traversable?(map_data, from, to, terrain) and
         new_cost < Map.get(distances, to, :infinity) do
      {:gb_sets.add({new_cost, to}, queue), Map.put(distances, to, new_cost)}
    else
      {queue, distances}
    end
  end

  defp step_traversable?(map_data, from, to, :runtime) do
    Cell.step_traversable?(map_data.name, from, to, [])
  end

  defp step_traversable?(map_data, {from_x, from_y}, {to_x, to_y}, :static) do
    dx = to_x - from_x
    dy = to_y - from_y

    MapData.walkable?(map_data, to_x, to_y) and
      (dx == 0 or dy == 0 or
         (MapData.walkable?(map_data, from_x + dx, from_y) and
            MapData.walkable?(map_data, from_x, from_y + dy)))
  end

  defp neighbors({x, y}) do
    straight = MovementEngine.straight_cost()
    diagonal = MovementEngine.diagonal_cost()

    [
      {{x, y - 1}, straight},
      {{x + 1, y}, straight},
      {{x, y + 1}, straight},
      {{x - 1, y}, straight},
      {{x + 1, y - 1}, diagonal},
      {{x + 1, y + 1}, diagonal},
      {{x - 1, y + 1}, diagonal},
      {{x - 1, y - 1}, diagonal}
    ]
  end

  defp valid_position?(%MapData{xs: width, ys: height}, {x, y}) do
    x >= 0 and x < width and y >= 0 and y < height
  end
end
