defmodule Aesir.ZoneServer.Mmo.Mechanics.StatCostTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.StatCost.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.StatCost.Renewal

  test "renewal preserves the post-100 cost curve" do
    for {value, expected} <- [{99, 11}, {100, 16}, {104, 16}, {105, 20}, {135, 44}] do
      assert Renewal.cost_to_raise(value) === expected
    end
  end

  test "pre-renewal uses the classic cost curve at decade boundaries" do
    # rAthena src/map/pc.cpp:8798-8804 (#else of RENEWAL_STAT).
    for {value, expected} <- [
          {0, 1},
          {1, 2},
          {9, 2},
          {10, 2},
          {11, 3},
          {99, 11},
          {100, 11},
          {101, 12},
          {104, 12},
          {105, 12},
          {135, 15}
        ] do
      assert PreRenewal.cost_to_raise(value) === expected
    end
  end

  test "pre-renewal caps primary stats and disables trait stats" do
    # rAthena src/map/pc.cpp:8816-8828,14338-14402,15234-15243.
    assert PreRenewal.max_parameter(0) === 99
    assert PreRenewal.max_parameter(4252) === 99
    assert PreRenewal.max_trait_parameter(0) === 0
    assert PreRenewal.max_trait_parameter(4252) === 0
  end
end
