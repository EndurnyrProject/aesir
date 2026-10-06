defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTimeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.Renewal
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  test "named stages preserve source binary32 conversions and reactions" do
    classic = definition([1_000])
    renewal = definition([1_000], [0])

    assert %{time: 699, reactions: []} =
             PreRenewal.early(classic, 1, %{dex: 0, int: 0, item_global_rate: 30})

    assert %{timing: %{total: 899}, reactions: []} =
             Renewal.late(renewal, 1, %{dex: 0, int: 0, statuses: %{suffragium: 10}}, 1_000)
  end

  test "classic late stage keeps Suffragium's truncation and reaction" do
    assert %{timing: %{total: 550}, reactions: [:end_suffragium]} =
             PreRenewal.late(
               definition([1_001]),
               1,
               %{dex: 0, int: 0, statuses: %{suffragium: 45}},
               1_001
             )
  end

  test "renewal signed status accumulation cancels Slow Cast and Suffragium" do
    assert %{timing: %{total: 1_000}} =
             Renewal.late(
               definition([1_000]),
               1,
               %{
                 dex: 0,
                 int: 0,
                 statuses: %{slowcast: 20, suffragium: 20}
               },
               1_000
             )
  end

  test "renewal explicit fixed time is additional and fallback requires a sentinel" do
    assert %{total: 800, variable: 500, fixed: 300} =
             Renewal.compute(definition([500], [300]), 1, %{dex: 0, int: 0})

    assert %{total: 502, variable: 402, fixed: 100} =
             Renewal.compute(definition([503], [-1]), 1, %{dex: 0, int: 0})

    assert %{total: 450} =
             Renewal.compute(definition([0], [1_000]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_flat: -99,
               item_global_fixed_rate: 50
             })
  end

  test "classic consumes eligible Foresight even when status reductions are ignored" do
    definition = %{definition([1_000]) | ignore_status_cast: true}
    inputs = %{dex: 0, int: 0, effective_skill?: true, statuses: %{memorize: true}}

    assert %{time: 1_000, reactions: [:consume_memorize]} =
             PreRenewal.early(definition, 1, inputs)

    assert %{time: 0, reactions: []} =
             PreRenewal.early(definition, 1, %{inputs | dex: 150})
  end

  test "classic per-skill items still apply when IgnoreItemBonus is set" do
    definition = %{definition([1_000]) | ignore_item_cast: true}

    assert %{time: 700} =
             PreRenewal.early(definition, 1, %{
               dex: 0,
               int: 0,
               item_global_rate: 80,
               item_skill_rate: -30
             })
  end

  test "renewal ignores status reactions with IgnoreStatus and includes the fifth charge" do
    definition = definition([1_000])
    inputs = %{dex: 0, int: 0, effective_skill?: true, statuses: %{memorize: true}}

    assert %{timing: %{total: 500}, reactions: [:consume_memorize]} =
             Renewal.late(definition, 1, inputs, 1_000)

    assert %{timing: %{total: 1_000}, reactions: []} =
             Renewal.late(%{definition | ignore_status_cast: true}, 1, inputs, 1_000)
  end

  test "renewal Radius overwrites the local level used by later fixed modifiers" do
    definition = %{definition([0, 0], [1_000, 1_000]) | id: 2_201}

    inputs = %{
      dex: 0,
      int: 30,
      base_level: 120,
      radius_level: 3,
      statuses: %{gloomy_day: true}
    }

    assert %{fixed: 1_875, total: 1_875} = Renewal.compute(definition, 2, inputs)

    assert %{fixed: 1_000, total: 1_000} =
             Renewal.compute(definition, 2, %{inputs | statuses: %{}})
  end

  test "renewal schedules from the final double addition, not truncated component sums" do
    result =
      Renewal.compute(definition([2_000_000_000], [100]), 1, %{
        dex: 0,
        int: 0,
        item_global_fixed_rate: 3,
        statuses: %{freezing: true}
      })

    assert result == %{variable: 2_000_000_000, fixed: 146, total: 2_000_000_147}
  end

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
      item_global_rate: 20,
      statuses: %{suffragium: 20}
    }

    # rAthena src/map/skill.cpp:10130-10254.
    assert PreRenewal.compute(definition([500]), 1, stats) === %{
             fixed: 0,
             variable: 308,
             total: 308
           }
  end

  test "pre-renewal applies the equipment and Bragi rate before the first truncation" do
    stats = %{dex: 1, int: 0, item_global_rate: 20}

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
      item_skill_rate: -30,
      item_global_rate: 20
    }

    assert PreRenewal.compute(definition([501]), 1, stats) === %{
             fixed: 0,
             variable: 278,
             total: 278
           }
  end

  test "pre-renewal applies Suffragium after the first truncation" do
    stats = %{dex: 1, int: 0, statuses: %{suffragium: 20}}

    assert PreRenewal.compute(definition([501]), 1, stats) === %{
             fixed: 0,
             variable: 397,
             total: 397
           }
  end

  test "pre-renewal adds Slow Cast before subtracting Suffragium" do
    stats = %{dex: 1, int: 0, statuses: %{slowcast: 20, suffragium: 20}}

    assert PreRenewal.compute(definition([501]), 1, stats) === %{
             fixed: 0,
             variable: 477,
             total: 477
           }
  end

  test "pre-renewal floors early reductions and caps late reductions" do
    for {stats, expected} <- [
          {%{item_skill_rate: -99}, 5},
          {%{item_skill_rate: -100}, 0},
          {%{item_skill_rate: -101}, 0},
          {%{item_global_rate: 99}, 5},
          {%{item_global_rate: 100}, 0},
          {%{item_global_rate: 101}, 0},
          {%{statuses: %{suffragium: 99}}, 5},
          {%{statuses: %{suffragium: 100}}, 0},
          {%{statuses: %{suffragium: 101}}, 0}
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
      {definition([1_000]), %{dex: 0, int: 0}, %{fixed: 0, variable: 1_000, total: 1_000}},
      {definition([1_000]), %{dex: 99, int: 99}, %{fixed: 0, variable: 251, total: 251}},
      {definition([1_000], [350]), %{dex: 0, int: 0, item_global_fixed_flat: -100},
       %{fixed: 250, variable: 1_000, total: 1_250}},
      {definition([1_000], [-1]), %{dex: 0, int: 0}, %{fixed: 200, variable: 800, total: 1_000}},
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
             fixed: 0,
             variable: 1_000,
             total: 1_000
           }

    assert PreRenewal.compute(pre_renewal_definition, 1, %{
             dex: 200,
             int: 200,
             item_global_rate: 20,
             item_skill_rate: -10,
             statuses: %{suffragium: 20}
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
