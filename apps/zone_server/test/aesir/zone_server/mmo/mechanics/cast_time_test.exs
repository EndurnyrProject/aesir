defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTimeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.Renewal
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  test "pre-renewal scales the single cast by DEX with integer truncation" do
    definition = definition([1_001])

    # rAthena src/map/skill.cpp:10130-10145; conf/battle/skill.conf:51.
    for {dex, expected} <- [
          {0, 1_001},
          {1, 994},
          {75, 500},
          {99, 340},
          {149, 6},
          {150, 0},
          {200, 0}
        ] do
      assert PreRenewal.compute(definition, 1, %{dex: dex, int: 999}) === %{
               fixed: 0,
               variable: expected,
               total: expected
             }
    end
  end

  test "pre-renewal truncates the early rate before Suffragium" do
    stats = %{
      dex: 5,
      int: 0,
      varcast_reductions: [20, 20],
      varcast_rate: 0,
      fixed_cast: -500,
      fixcast_rate: -100,
      classic_early_rate: -20,
      classic_skill_rate: 0,
      classic_late_reductions: [20]
    }

    # rAthena src/map/skill.cpp:10130-10254.
    assert PreRenewal.compute(definition([500]), 1, stats) === %{
             fixed: 0,
             variable: 308,
             total: 308
           }
  end

  test "pre-renewal applies the equipment and Bragi rate before the first truncation" do
    stats = %{dex: 1, int: 0, classic_early_rate: -20}

    assert PreRenewal.compute(definition([501]), 1, stats) === %{
             fixed: 0,
             variable: 398,
             total: 398
           }
  end

  test "pre-renewal keeps per-skill and global early rates source-aware" do
    stats = %{
      dex: 1,
      int: 0,
      classic_skill_rate: -30,
      classic_early_rate: -20
    }

    assert PreRenewal.compute(definition([501]), 1, stats) === %{
             fixed: 0,
             variable: 278,
             total: 278
           }
  end

  test "pre-renewal applies Suffragium after the first truncation" do
    stats = %{dex: 1, int: 0, classic_late_reductions: [20]}

    assert PreRenewal.compute(definition([501]), 1, stats) === %{
             fixed: 0,
             variable: 397,
             total: 397
           }
  end

  test "pre-renewal applies every late reduction and truncates at the end" do
    stats = %{dex: 1, int: 0, classic_late_reductions: [20, 20]}

    assert PreRenewal.compute(definition([501]), 1, stats) === %{
             fixed: 0,
             variable: 318,
             total: 318
           }
  end

  test "pre-renewal floors early reductions and caps late reductions" do
    for {stats, expected} <- [
          {%{classic_skill_rate: -99}, 5},
          {%{classic_skill_rate: -100}, 0},
          {%{classic_skill_rate: -101}, 0},
          {%{classic_early_rate: -99}, 5},
          {%{classic_early_rate: -100}, 0},
          {%{classic_early_rate: -101}, 0},
          {%{classic_late_reductions: [99]}, 5},
          {%{classic_late_reductions: [100]}, 0},
          {%{classic_late_reductions: [101]}, 0}
        ] do
      assert PreRenewal.compute(definition([501]), 1, Map.merge(%{dex: 0, int: 0}, stats)) === %{
               fixed: 0,
               variable: expected,
               total: expected
             }
    end
  end

  test "pre-renewal ignores fixed cast time when the base cast is instant" do
    assert PreRenewal.compute(definition([0], [500]), 1, %{dex: 0, int: 0}) === %{
             fixed: 0,
             variable: 0,
             total: 0
           }
  end

  test "renewal preserves the fixed and variable cast split" do
    cases = [
      {definition([1_000]), %{dex: 0, int: 0}, %{fixed: 200, variable: 800, total: 1_000}},
      {definition([1_000]), %{dex: 99, int: 99}, %{fixed: 200, variable: 201, total: 401}},
      {definition([1_000], [350]), %{dex: 0, int: 0, fixed_cast: -100},
       %{fixed: 250, variable: 650, total: 900}},
      {definition([0]), %{dex: 50, int: 50}, %{fixed: 0, variable: 0, total: 0}}
    ]

    # rAthena src/map/skill.cpp:10256-10382; src/map/battle.cpp:8753.
    for {definition, stats, expected} <- cases do
      assert Renewal.compute(definition, 1, stats) == expected
    end
  end

  test "ignore_dex skips each ruleset's stat reduction" do
    renewal_definition = definition([1_000], [], true)
    pre_renewal_definition = definition([1_001], [500], true)

    # rAthena src/map/skill.cpp:10135-10145, 10374-10376.
    assert Renewal.compute(renewal_definition, 1, %{dex: 200, int: 200}) == %{
             fixed: 200,
             variable: 800,
             total: 1_000
           }

    assert PreRenewal.compute(pre_renewal_definition, 1, %{
             dex: 200,
             int: 200,
             varcast_reductions: [20, 20],
             varcast_rate: -20,
             fixed_cast: -500,
             fixcast_rate: -100,
             classic_early_rate: -20,
             classic_skill_rate: -10,
             classic_late_reductions: [20]
           }) === %{
             fixed: 0,
             variable: 576,
             total: 576
           }
  end

  defp definition(cast_time, fixed_cast_time \\ [], ignore_dex \\ false) do
    %Definition{
      id: 83,
      name: :test_skill,
      display_name: "Test Skill",
      max_level: 10,
      cast_time: cast_time,
      fixed_cast_time: fixed_cast_time,
      ignore_dex: ignore_dex
    }
  end
end
