defmodule Aesir.ZoneServer.Unit.ConfusedWalk do
  @moduledoc """
  Where a confused unit really walks. Every walk request of a unit holding
  Confusion has its destination replaced by a random walkable cell about as far
  away as the requested one, in both modes.

  The random cell: with `d2` the squared distance to the requested cell and
  `d = max(1, trunc(sqrt(d2)))`, one of the four diagonal directions is picked,
  then a distance `s` in `1..d` along its x axis and `trunc(sqrt(d2 - s * s))`
  along its y axis. A cell that is not walkable, or that no straight-line walk
  reaches, is rejected and another one picked, up to 100 tries; after 100
  rejections the requested cell is kept.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Pathfinding

  @diagonals [{-1, 1}, {-1, -1}, {1, -1}, {1, 1}]
  @tries 100

  @typedoc "Draws a random integer in `min..max`, both ends included."
  @type roll :: (integer(), integer() -> integer())

  @doc """
  The destination a walk request of `{unit_type, unit_id}` from `from` to `to`
  walks to: `to`, or a random cell (`random_destination/4`) while the unit
  holds Confusion.
  """
  @spec destination(atom(), integer(), String.t(), {integer(), integer()}, {integer(), integer()}) ::
          {integer(), integer()}
  def destination(unit_type, unit_id, map_name, from, to) do
    if StatusStorage.has_status?(unit_type, unit_id, :sc_confusion),
      do: random_destination(map_name, from, to),
      else: to
  end

  @doc """
  A random walkable cell about as far from `from` as `to` is, or `to` after
  100 rejected cells. `roll` draws each random number.
  """
  @spec random_destination(String.t(), {integer(), integer()}, {integer(), integer()}, roll()) ::
          {integer(), integer()}
  def random_destination(map_name, {x, y} = from, {to_x, to_y} = to, roll \\ &roll/2) do
    dist2 = (to_x - x) * (to_x - x) + (to_y - y) * (to_y - y)
    dist = max(isqrt(dist2), 1)

    Enum.find_value(1..@tries, to, fn _try ->
      {dir_x, dir_y} = Enum.at(@diagonals, roll.(0, 3))
      segment = roll.(1, dist)
      cell = {x + segment * dir_x, y + isqrt(dist2 - segment * segment) * dir_y}

      if reachable?(map_name, from, cell), do: cell
    end)
  end

  # The reference's reach check: the cell is passable and the straight walk to
  # it searches with CELL_CHKNOREACH (the map's last row and column open).
  defp reachable?(map_name, from, {cell_x, cell_y} = cell) do
    with true <- Cell.traversable?(map_name, cell_x, cell_y),
         {:ok, map_data} <- MapCache.get(map_name),
         {:ok, _path} <- Pathfinding.find_path(map_data, from, cell, easy: true, cells: :noreach) do
      true
    else
      _ -> false
    end
  end

  # The square root truncated to an integer. A negative argument (a request for
  # the unit's own cell) gives 0, as the float-to-integer conversion of its NaN does.
  defp isqrt(n) when n < 0, do: 0
  defp isqrt(n), do: trunc(:math.sqrt(n))

  defp roll(min, max), do: min + :rand.uniform(max - min + 1) - 1
end
