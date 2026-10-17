defmodule Aesir.ZoneServer.Unit.ConfusedWalkTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.ConfusedWalk

  @map "confused_walk_map"

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    :ok
  end

  describe "random_destination/4" do
    test "picks a diagonal, then a distance along x and the rest of the distance along y" do
      # From (30, 30) to (30, 35): squared distance 25, distance 5. Direction 3 is
      # north-east (+1, +1); x moves 3, y moves trunc(sqrt(25 - 9)) = 4.
      assert ConfusedWalk.random_destination(@map, {30, 30}, {30, 35}, rolls([3, 3])) == {33, 34}

      # Direction 0 is (-1, +1); x moves 5, y moves 0.
      assert ConfusedWalk.random_destination(@map, {30, 30}, {30, 35}, rolls([0, 5])) == {25, 30}
    end

    test "rejects a cell that is not walkable or that no straight walk reaches" do
      block(33, 34)

      assert ConfusedWalk.random_destination(@map, {30, 30}, {30, 35}, rolls([3, 3, 0, 5])) ==
               {25, 30}

      block(27, 30)

      assert ConfusedWalk.random_destination(@map, {30, 30}, {30, 35}, rolls([0, 5, 2, 1])) ==
               {31, 26}
    end

    test "keeps the requested cell after 100 rejected cells" do
      block(33, 34)
      always = fn _min, _max -> 3 end

      assert ConfusedWalk.random_destination(@map, {30, 30}, {30, 35}, always) == {30, 35}
    end

    test "a request for the unit's own cell moves it one cell along x" do
      assert ConfusedWalk.random_destination(@map, {30, 30}, {30, 30}, rolls([3, 1])) == {31, 30}
    end
  end

  describe "destination/5" do
    test "keeps the requested cell for a unit without Confusion" do
      assert ConfusedWalk.destination(:mob, 4_001, @map, {30, 30}, {30, 35}) == {30, 35}
    end

    test "randomizes it for a confused unit" do
      :ok = StatusStorage.apply_status(:mob, 4_002, :sc_confusion, duration: 60_000)

      destination = ConfusedWalk.destination(:mob, 4_002, @map, {30, 30}, {30, 35})

      assert destination in candidates({30, 30}, 25)
    end
  end

  defp rolls(values) do
    {:ok, agent} = Agent.start_link(fn -> values end)
    fn _min, _max -> Agent.get_and_update(agent, fn [value | rest] -> {value, rest} end) end
  end

  defp block(x, y), do: :ok = Cell.put(@map, x, y, :barrier, x * 1_000 + y, blocks_movement: true)

  defp candidates({x, y}, dist2) do
    dist = trunc(:math.sqrt(dist2))

    for {dx, dy} <- [{-1, 1}, {-1, -1}, {1, -1}, {1, 1}], s <- 1..dist do
      {x + s * dx, y + trunc(:math.sqrt(dist2 - s * s)) * dy}
    end
  end
end
