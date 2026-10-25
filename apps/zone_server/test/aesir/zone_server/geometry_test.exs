defmodule Aesir.ZoneServer.GeometryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Geometry

  describe "sector_step/2" do
    test "a zero offset is east" do
      assert Geometry.sector_step(0, 0) == {1, 0}
    end

    test "a cardinal direction covers offsets up to a 1:3 slope of its axis, diagonals the rest" do
      assert Geometry.sector_step(3, 1) == {1, 0}
      assert Geometry.sector_step(2, 1) == {1, 1}
      assert Geometry.sector_step(1, 3) == {1, 1}
      assert Geometry.sector_step(1, 4) == {0, 1}
      assert Geometry.sector_step(-3, -1) == {-1, -1}
      assert Geometry.sector_step(-4, -1) == {-1, 0}
      assert Geometry.sector_step(-1, 3) == {0, 1}
      assert Geometry.sector_step(1, -4) == {0, -1}
    end
  end

  describe "client_distance/4" do
    test "counts a straight line of n cells as n - 1 and truncates diagonals" do
      assert Geometry.client_distance(0, 0, 0, 0) == 0
      assert Geometry.client_distance(0, 0, 1, 0) == 0
      assert Geometry.client_distance(0, 0, 10, 0) == 9
      assert Geometry.client_distance(0, 0, 0, -10) == 9
      # sqrt(2) - 0.1 = 1.31; sqrt(200) - 0.1 = 14.04
      assert Geometry.client_distance(0, 0, 1, 1) == 1
      assert Geometry.client_distance(5, 5, 15, 15) == 14
    end
  end

  describe "chebyshev_distance/4" do
    test "calculates correct distance for adjacent cells" do
      # Horizontal distance
      assert Geometry.chebyshev_distance(0, 0, 1, 0) == 1
      assert Geometry.chebyshev_distance(0, 0, -1, 0) == 1

      # Vertical distance
      assert Geometry.chebyshev_distance(0, 0, 0, 1) == 1
      assert Geometry.chebyshev_distance(0, 0, 0, -1) == 1
    end

    test "calculates correct distance for diagonal cells" do
      # Diagonal moves count as 1 cell in tile-based games
      assert Geometry.chebyshev_distance(0, 0, 1, 1) == 1
      assert Geometry.chebyshev_distance(0, 0, -1, -1) == 1
      assert Geometry.chebyshev_distance(0, 0, 1, -1) == 1
      assert Geometry.chebyshev_distance(0, 0, -1, 1) == 1
    end

    test "calculates correct distance for multi-cell ranges" do
      # 2 cells away
      assert Geometry.chebyshev_distance(0, 0, 2, 0) == 2
      assert Geometry.chebyshev_distance(0, 0, 0, 2) == 2
      assert Geometry.chebyshev_distance(0, 0, 2, 2) == 2

      # 3 cells away
      assert Geometry.chebyshev_distance(0, 0, 3, 0) == 3
      assert Geometry.chebyshev_distance(0, 0, 0, 3) == 3
      assert Geometry.chebyshev_distance(0, 0, 3, 3) == 3
    end

    test "handles mixed distances correctly" do
      # When one axis is longer, that's the distance
      assert Geometry.chebyshev_distance(0, 0, 3, 1) == 3
      assert Geometry.chebyshev_distance(0, 0, 1, 3) == 3
      assert Geometry.chebyshev_distance(0, 0, 5, 2) == 5
      assert Geometry.chebyshev_distance(0, 0, 2, 5) == 5
    end

    test "calculates same distance regardless of direction" do
      # Should be symmetric
      assert Geometry.chebyshev_distance(0, 0, 3, 2) == Geometry.chebyshev_distance(3, 2, 0, 0)
      assert Geometry.chebyshev_distance(5, 7, 2, 3) == Geometry.chebyshev_distance(2, 3, 5, 7)
    end
  end

  describe "in_tile_range?/5" do
    test "correctly identifies cells within range" do
      # Range 1 - adjacent cells
      assert Geometry.in_tile_range?(0, 0, 1, 0, 1) == true
      assert Geometry.in_tile_range?(0, 0, 0, 1, 1) == true
      assert Geometry.in_tile_range?(0, 0, 1, 1, 1) == true

      # Range 2 - 2 cells away
      assert Geometry.in_tile_range?(0, 0, 2, 0, 2) == true
      assert Geometry.in_tile_range?(0, 0, 2, 2, 2) == true
      assert Geometry.in_tile_range?(0, 0, 2, 1, 2) == true
    end

    test "correctly identifies cells outside range" do
      # Range 1 - cells too far
      assert Geometry.in_tile_range?(0, 0, 2, 0, 1) == false
      assert Geometry.in_tile_range?(0, 0, 0, 2, 1) == false
      assert Geometry.in_tile_range?(0, 0, 2, 2, 1) == false

      # Range 2 - cells too far
      assert Geometry.in_tile_range?(0, 0, 3, 0, 2) == false
      assert Geometry.in_tile_range?(0, 0, 3, 3, 2) == false
    end
  end

  describe "behind?/2" do
    test "identifies rear, front, and side positions for every target facing" do
      target = fn dir -> %{x: 10, y: 10, dir: dir} end

      for {dir, rear, front, left_side, right_side} <- [
            {0, {10, 9}, {10, 11}, {9, 10}, {11, 10}},
            {1, {11, 9}, {9, 11}, {9, 9}, {11, 11}},
            {2, {11, 10}, {9, 10}, {10, 9}, {10, 11}},
            {3, {11, 11}, {9, 9}, {9, 11}, {11, 9}},
            {4, {10, 11}, {10, 9}, {9, 10}, {11, 10}},
            {5, {9, 11}, {11, 9}, {11, 11}, {9, 9}},
            {6, {9, 10}, {11, 10}, {10, 11}, {10, 9}},
            {7, {9, 9}, {11, 11}, {11, 9}, {9, 11}}
          ] do
        assert Geometry.behind?(position(rear), target.(dir))
        refute Geometry.behind?(position(front), target.(dir))
        refute Geometry.behind?(position(left_side), target.(dir))
        refute Geometry.behind?(position(right_side), target.(dir))
      end
    end

    test "includes the diagonals adjacent to directly behind" do
      target = %{x: 10, y: 10, dir: 4}

      assert Geometry.behind?(position({10, 11}), target)
      assert Geometry.behind?(position({9, 11}), target)
      assert Geometry.behind?(position({11, 11}), target)
    end

    defp position({x, y}), do: %{x: x, y: y}
  end

  describe "path_cells/4" do
    test "cardinal lanes include their origin, width and last cell" do
      cells = Geometry.path_cells({0, 0}, {9, 1}, 14, 1)

      for cell <- [{0, 0}, {13, 1}, {0, -1}, {9, 1}], do: assert(MapSet.member?(cells, cell))
      for cell <- [{14, 0}, {9, 2}], do: refute(MapSet.member?(cells, cell))

      boundary = Geometry.path_cells({0, 0}, {9, 3}, 14, 1)
      assert MapSet.member?(boundary, {9, 1})
      refute MapSet.member?(boundary, {9, 3})
    end

    test "diagonal lanes use rotated length and width bounds" do
      cells = Geometry.path_cells({0, 0}, {9, 4}, 14, 1)
      for cell <- [{0, 0}, {5, 4}, {6, 7}, {13, 13}], do: assert(MapSet.member?(cells, cell))
      for cell <- [{8, 1}, {14, 14}], do: refute(MapSet.member?(cells, cell))
      assert cells == Geometry.path_cells({0, 0}, {5, 4}, 14, 1)
    end

    test "lanes reflect in every direction and same-cell aim faces east" do
      east = Geometry.path_cells({0, 0}, {9, 1}, 14, 1)
      northeast = Geometry.path_cells({0, 0}, {5, 4}, 14, 1)

      for sx <- [-1, 1], sy <- [-1, 1] do
        assert Geometry.path_cells({20, 20}, {20 + sx * 9, 20 + sy}, 14, 1) ==
                 MapSet.new(east, fn {x, y} -> {20 + sx * x, 20 + sy * y} end)

        assert Geometry.path_cells({20, 20}, {20 + sx * 5, 20 + sy * 4}, 14, 1) ==
                 MapSet.new(northeast, fn {x, y} -> {20 + sx * x, 20 + sy * y} end)
      end

      same_cell = Geometry.path_cells({0, 0}, {0, 0}, 14, 1)
      assert same_cell == Geometry.path_cells({0, 0}, {9, 0}, 14, 1)
      assert MapSet.member?(same_cell, {13, 1})
      refute MapSet.member?(same_cell, {-1, 0})
    end
  end

  describe "path_cells/5" do
    test "the lane faces the nearest direction, with the uneven western boundaries" do
      step = fn {dx, dy} ->
        {0, 0} |> Geometry.path_cells({dx, dy}, 2, 0) |> MapSet.delete({0, 0}) |> Enum.at(0)
      end

      assert step.({3, 1}) == {1, 0}
      assert step.({1, 3}) == {1, 1}
      assert step.({3, -1}) == {1, 0}
      assert step.({1, -3}) == {1, -1}
      assert step.({-3, -1}) == {-1, -1}
      assert step.({-1, -3}) == {0, -1}
      assert step.({-3, 1}) == {-1, 1}
      assert step.({-1, 3}) == {0, 1}
      assert step.({0, 0}) == {1, 0}
    end

    test "an offset lane starts that many rows out" do
      assert Geometry.path_cells({0, 0}, {9, 0}, 1, 2, 2) == MapSet.new(-2..2, &{2, &1})
      assert Geometry.path_cells({0, 0}, {0, -9}, 2, 0, 3) == MapSet.new([{0, -3}, {0, -4}])
    end

    test "diagonal offsets count half-tile rows, so consecutive rows tile the lane" do
      assert Geometry.path_cells({0, 0}, {5, 5}, 1, 0, 2) == MapSet.new([{2, 2}])

      rows =
        [Geometry.path_cells({0, 0}, {5, 5}, 2, 2, 0)] ++
          for(offset <- 2..4, do: Geometry.path_cells({0, 0}, {5, 5}, 1, 2, offset))

      lane = Geometry.path_cells({0, 0}, {5, 5}, 5, 2, 0)

      assert Enum.reduce(rows, &MapSet.union/2) == lane
      assert Enum.sum(Enum.map(rows, &MapSet.size/1)) == MapSet.size(lane)
    end
  end

  describe "line_cells/4" do
    test "walks a horizontal line inclusive of both endpoints" do
      assert Geometry.line_cells(0, 0, 4, 0) == [{0, 0}, {1, 0}, {2, 0}, {3, 0}, {4, 0}]
    end

    test "walks a vertical line inclusive of both endpoints" do
      assert Geometry.line_cells(0, 0, 0, 4) == [{0, 0}, {0, 1}, {0, 2}, {0, 3}, {0, 4}]
    end

    test "walks a diagonal line with no gaps" do
      assert Geometry.line_cells(0, 0, 3, 3) == [{0, 0}, {1, 1}, {2, 2}, {3, 3}]
    end

    test "walks a diagonal line in the negative direction" do
      assert Geometry.line_cells(3, 3, 0, 0) == [{3, 3}, {2, 2}, {1, 1}, {0, 0}]
    end

    test "pins the exact cell sequence for an in-spear-range shallow diagonal" do
      assert Geometry.line_cells(0, 0, 2, 1) == [{0, 0}, {1, 0}, {2, 1}]
      assert Geometry.line_cells(0, 0, 1, 2) == [{0, 0}, {0, 1}, {1, 2}]
      assert Geometry.line_cells(2, 1, 0, 0) == [{2, 1}, {1, 1}, {0, 0}]
    end

    test "walks a shallow non-45-degree line with every step adjacent to the last" do
      cells = Geometry.line_cells(0, 0, 4, 1)

      assert List.first(cells) == {0, 0}
      assert List.last(cells) == {4, 1}

      cells
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [{x1, y1}, {x2, y2}] ->
        assert Geometry.chebyshev_distance(x1, y1, x2, y2) == 1
      end)
    end

    test "a single-cell line returns just that cell" do
      assert Geometry.line_cells(5, 5, 5, 5) == [{5, 5}]
    end
  end
end
