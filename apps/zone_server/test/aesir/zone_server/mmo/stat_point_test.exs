defmodule Aesir.ZoneServer.Mmo.StatPointTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatPoint

  describe "points_at/1 and gain/2" do
    test "level 1 starts at 48 cumulative points" do
      assert StatPoint.points_at(1) == 48
    end

    test "gain for one level-up is the table delta" do
      assert StatPoint.gain(1, 2) == 3
      assert StatPoint.gain(5, 6) == 4
    end

    test "gain sums correctly across multiple levels" do
      assert StatPoint.gain(1, 3) == StatPoint.points_at(3) - 48
    end

    test "gain stays correct past the level-105 non-formula region" do
      assert StatPoint.gain(110, 111) == StatPoint.points_at(111) - StatPoint.points_at(110)
      assert StatPoint.gain(110, 111) > 0
    end

    test "points_at clamps above the max level" do
      assert StatPoint.points_at(999) == StatPoint.points_at(275)
    end
  end

  describe "cost formula" do
    test "cost_to_raise uses the renewal formula at boundaries" do
      assert StatPoint.cost_to_raise(1) == 2
      assert StatPoint.cost_to_raise(9) == 2
      assert StatPoint.cost_to_raise(10) == 2
      assert StatPoint.cost_to_raise(11) == 3
      assert StatPoint.cost_to_raise(99) == 11
      assert StatPoint.cost_to_raise(100) == 16
      assert StatPoint.cost_to_raise(105) == 20
    end

    test "points_needed sums per-point costs" do
      assert StatPoint.points_needed(5, 0) == 0
      assert StatPoint.points_needed(5, 1) == StatPoint.cost_to_raise(5)

      assert StatPoint.points_needed(9, 3) ==
               StatPoint.cost_to_raise(9) + StatPoint.cost_to_raise(10) +
                 StatPoint.cost_to_raise(11)
    end

    test "max_increase is bounded by available points" do
      assert StatPoint.max_increase(5, 1, 99) == 0
      assert StatPoint.max_increase(5, 2, 99) == 1
      assert StatPoint.max_increase(5, 4, 99) == 2
    end

    test "max_increase is bounded by the parameter cap" do
      assert StatPoint.max_increase(98, 1_000, 99) == 1
      assert StatPoint.max_increase(99, 1_000, 99) == 0
    end

    test "max_parameter is 99 for current jobs" do
      assert StatPoint.max_parameter(0) == 99
    end
  end
end
