defmodule Aesir.ZoneServer.Unit.MovementEngineTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.MovementEngine

  describe "calculate_movement_budget/2" do
    test "calculates correct budget for given elapsed time and walk speed" do
      # Walk speed 150 means 1.0/150 cells per millisecond
      # 150ms elapsed should give budget of 1.0 
      assert MovementEngine.calculate_movement_budget(150, 150) == 1.0

      # 300ms elapsed should give budget of 2.0
      assert MovementEngine.calculate_movement_budget(300, 150) == 2.0

      # Higher walk speed means faster movement (lower denominator)
      # 100ms with speed 100 should give budget of 1.0
      assert MovementEngine.calculate_movement_budget(100, 100) == 1.0
    end
  end

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

  describe "consume_path_with_budget/4" do
    test "consumes no path when budget is zero" do
      path = [{1, 0}, {2, 0}, {3, 0}]

      {x, y, remaining_path, consumed} =
        MovementEngine.consume_path_with_budget(0, 0, path, 0.0)

      assert {x, y} == {0, 0}
      assert remaining_path == path
      assert consumed == 0.0
    end

    test "consumes straight path with sufficient budget" do
      path = [{1, 0}, {2, 0}]
      # Enough for both straight moves (1.0 + 1.0 = 2.0)
      budget = 2.5

      {x, y, remaining_path, consumed} =
        MovementEngine.consume_path_with_budget(0, 0, path, budget)

      assert {x, y} == {2, 0}
      assert remaining_path == []
      assert consumed == 2.0
    end

    test "consumes diagonal path correctly" do
      path = [{1, 1}, {2, 2}]
      # Enough for both diagonal moves (1.414 + 1.414 = 2.828)
      budget = 3.0

      {x, y, remaining_path, consumed} =
        MovementEngine.consume_path_with_budget(0, 0, path, budget)

      assert {x, y} == {2, 2}
      assert remaining_path == []
      assert_in_delta consumed, 2.828, 0.01
    end

    test "stops when budget is insufficient" do
      path = [{1, 0}, {2, 0}, {3, 0}]
      # Only enough for first move (1.0), not second
      budget = 1.5

      {x, y, remaining_path, consumed} =
        MovementEngine.consume_path_with_budget(0, 0, path, budget)

      assert {x, y} == {1, 0}
      assert remaining_path == [{2, 0}, {3, 0}]
      assert consumed == 1.0
    end

    test "handles mixed straight and diagonal path" do
      # Straight then diagonal
      path = [{1, 0}, {2, 1}]
      # Enough for both (1.0 + 1.414 = 2.414)
      budget = 2.5

      {x, y, remaining_path, consumed} =
        MovementEngine.consume_path_with_budget(0, 0, path, budget)

      assert {x, y} == {2, 1}
      assert remaining_path == []
      assert_in_delta consumed, 2.414, 0.01
    end

    test "handles empty path" do
      {x, y, remaining_path, consumed} =
        MovementEngine.consume_path_with_budget(5, 5, [], 10.0)

      assert {x, y} == {5, 5}
      assert remaining_path == []
      assert consumed == 0.0
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
