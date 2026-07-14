defmodule Aesir.ZoneServer.Map.LineOfSightTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapData

  test "rAthena integer traversal catches the diagonal cell symmetric Bresenham skips" do
    map =
      "prontera"
      |> MapData.new(100, 100)
      |> MapData.set_cell(51, 60, GatType.wall())

    refute LineOfSight.clear?(map, {50, 60}, {54, 62})
  end

  test "dynamic Ice Wall blocks a traversed diagonal cell" do
    map =
      "prontera"
      |> MapData.new(100, 100)
      |> MapData.set_cell_flag(51, 60, :icewall, true)

    refute LineOfSight.clear?(map, {50, 60}, {54, 62})
  end

  test "a blocked destination cell is not counted as an intervening obstruction" do
    map =
      "prontera"
      |> MapData.new(100, 100)
      |> MapData.set_cell(54, 62, GatType.wall())
      |> MapData.set_cell_flag(54, 62, :icewall, true)

    assert LineOfSight.clear?(map, {50, 60}, {54, 62})
  end
end
