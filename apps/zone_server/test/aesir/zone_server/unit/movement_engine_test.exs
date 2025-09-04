defmodule Aesir.ZoneServer.Unit.MovementEngineTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.MovementEngine

  describe "get_movement_cost/2" do
    test "returns straight cost for horizontal/vertical movement" do
      assert MovementEngine.get_movement_cost({0, 0}, {1, 0}) == 1.0
      assert MovementEngine.get_movement_cost({0, 0}, {0, 1}) == 1.0
      assert MovementEngine.get_movement_cost({5, 5}, {5, 6}) == 1.0
      assert MovementEngine.get_movement_cost({5, 5}, {4, 5}) == 1.0
    end

    test "returns diagonal cost for diagonal movement" do
      assert MovementEngine.get_movement_cost({0, 0}, {1, 1}) == 1.414
      assert MovementEngine.get_movement_cost({5, 5}, {6, 6}) == 1.414
      assert MovementEngine.get_movement_cost({5, 5}, {4, 4}) == 1.414
      assert MovementEngine.get_movement_cost({5, 5}, {6, 4}) == 1.414
    end
  end

  describe "constants" do
    test "straight_cost returns expected value" do
      assert MovementEngine.straight_cost() == 1.0
    end

    test "diagonal_cost returns expected value" do
      assert MovementEngine.diagonal_cost() == 1.414
    end
  end
end
