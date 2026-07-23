defmodule Aesir.ZoneServer.GeometryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Geometry

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
