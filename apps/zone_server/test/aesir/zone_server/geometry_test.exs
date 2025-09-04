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

  describe "distance calculation comparison" do
    test "chebyshev vs euclidean distance for combat scenarios" do
      # For RO tile-based movement, diagonal moves should count as 1
      # Euclidean would give sqrt(2) ≈ 1.414, but Chebyshev gives 1
      assert Geometry.chebyshev_distance(0, 0, 1, 1) == 1
      assert Geometry.distance(0, 0, 1, 1) |> Float.round(3) == 1.414

      # This demonstrates why Chebyshev is correct for RO:
      # A player can move diagonally in one step
      assert Geometry.chebyshev_distance(0, 0, 2, 2) == 2
      assert Geometry.distance(0, 0, 2, 2) |> Float.round(3) == 2.828
    end
  end
end
