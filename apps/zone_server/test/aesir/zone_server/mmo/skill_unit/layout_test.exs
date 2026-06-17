defmodule Aesir.ZoneServer.Mmo.SkillUnit.LayoutTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.SkillUnit.Layout

  describe "square/2" do
    test "radius 2 returns the 25-cell 5x5 block centered on the point" do
      cells = Layout.square({100, 100}, 2)

      expected = for x <- 98..102, y <- 98..102, do: {x, y}

      assert length(cells) == 25
      assert Enum.sort(cells) == Enum.sort(expected)
    end

    test "radius 0 returns a single cell at the center" do
      assert Layout.square({100, 100}, 0) == [{100, 100}]
    end

    test "radius 1 returns 9 cells" do
      cells = Layout.square({100, 100}, 1)

      assert length(cells) == 9
      assert Enum.uniq(cells) == cells
    end
  end
end
