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
    test "displayed next cost is zero at the cap without changing raw spending costs" do
      assert StatPoint.next_cost(98, 1) == 11
      assert StatPoint.next_cost(99, 1) == 0
      assert StatPoint.next_cost(100, 1) == 0
      assert StatPoint.cost_to_raise(99) == 11
    end

    @tag game_mode: :renewal
    test "displayed next cost respects the higher trait-job primary cap" do
      assert StatPoint.next_cost(134, 4252) == 40
      assert StatPoint.next_cost(135, 4252) == 0
      assert StatPoint.cost_to_raise(135) == 44
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

  describe "trait_points_at/1 and trait_gain/2" do
    test "trait points are 0 through level 200" do
      assert StatPoint.trait_points_at(200) == 0
    end

    @tag game_mode: :renewal
    test "trait points are cumulative from level 201" do
      assert StatPoint.trait_points_at(201) == 3
      assert StatPoint.trait_points_at(205) == 19
      assert StatPoint.trait_points_at(275) == 285
    end

    @tag game_mode: :renewal
    test "trait_gain is the cumulative table delta" do
      assert StatPoint.trait_gain(200, 201) == 3
      assert StatPoint.trait_gain(204, 205) == 7
    end

    @tag game_mode: :pre_renewal
    test "classic has no trait grants even at levels present in the shared point table" do
      assert StatPoint.trait_points_at(201) == 0
      assert StatPoint.trait_points_at(275) == 0
      assert StatPoint.trait_gain(200, 205) == 0
    end

    test "trait_gain is 0 below level 201" do
      assert StatPoint.trait_gain(1, 200) == 0
    end
  end

  describe "job-aware caps" do
    @tag game_mode: :renewal
    test "max_parameter is 135 for trait jobs and 99 otherwise" do
      assert StatPoint.max_parameter(4252) == 135
      assert StatPoint.max_parameter(4054) == 99
    end

    @tag game_mode: :renewal
    test "max_trait_parameter is 100 for trait jobs and 0 otherwise" do
      assert StatPoint.max_trait_parameter(4252) == 100
      assert StatPoint.max_trait_parameter(4054) == 0
    end

    @tag game_mode: :pre_renewal
    test "classic caps primary stats at 99 and refuses all trait allocation" do
      for job <- [0, 1, 4054, 4252] do
        assert StatPoint.max_parameter(job) == 99
        assert StatPoint.max_trait_parameter(job) == 0
      end
    end
  end
end

defmodule Aesir.ZoneServer.Mmo.StatPointCostTest do
  use ExUnit.Case,
    async: true,
    parameterize: [
      %{value: 0, renewal: 2, classic: 1},
      %{value: 1, renewal: 2, classic: 2},
      %{value: 9, renewal: 2, classic: 2},
      %{value: 10, renewal: 2, classic: 2},
      %{value: 11, renewal: 3, classic: 3},
      %{value: 99, renewal: 11, classic: 11},
      %{value: 100, renewal: 16, classic: 11},
      %{value: 104, renewal: 16, classic: 12},
      %{value: 105, renewal: 20, classic: 12},
      %{value: 135, renewal: 44, classic: 15}
    ]

  alias Aesir.ZoneServer.Mmo.StatPoint

  @tag game_mode: :renewal
  test "Renewal cost at each boundary", %{value: value, renewal: expected} do
    assert StatPoint.cost_to_raise(value) == expected
  end

  @tag game_mode: :pre_renewal
  test "classic cost at each boundary", %{value: value, classic: expected} do
    assert StatPoint.cost_to_raise(value) == expected
  end
end
