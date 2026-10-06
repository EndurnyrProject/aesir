defmodule Aesir.ZoneServer.Mmo.Skill.CastTimeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  defp definition(cast_time, fixed_cast_time \\ [-1]) do
    %Definition{
      id: 83,
      name: :test_skill,
      display_name: "Test Skill",
      max_level: 10,
      cast_time: cast_time,
      fixed_cast_time: fixed_cast_time
    }
  end

  describe "compute/3 shared behavior" do
    test "instant when the base cast time is 0" do
      assert CastTime.compute(definition([0]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "instant when the cast_time list is empty for the level" do
      assert CastTime.compute(definition([]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "reads the per-level cast time array" do
      assert %{total: total} =
               CastTime.compute(definition([1_000, 2_000, 3_000]), 3, %{dex: 0, int: 0})

      assert total == 3_000
    end

    @tag game_mode: :pre_renewal
    test "classic ignores fixed-cast item bonuses on an instant skill" do
      assert CastTime.compute(definition([0]), 1, %{dex: 0, int: 0, item_global_fixed_flat: 500}) ==
               %{fixed: 0, variable: 0, total: 0}
    end
  end

  describe "compute/3 Renewal" do
    @describetag game_mode: :renewal

    test "uses an explicit fixed cast when the variable cast list is empty" do
      assert CastTime.compute(definition([], [500]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 500, variable: 0, total: 500}
    end

    test "a negative fixed sentinel splits 20% of the base" do
      assert %{fixed: 200} = CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0})
    end

    test "missing fixed time is zero rather than an implicit split" do
      assert CastTime.compute(definition([1_000], []), 1, %{dex: 0, int: 0}) ==
               %{fixed: 0, variable: 1_000, total: 1_000}
    end

    test "explicit fixed_cast_time is additional to the base variable cast" do
      assert %{fixed: 350, variable: 1_000, total: 1_350} =
               CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0})
    end

    test "variable is 0 once 2*DEX + INT reaches 530" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 150, int: 230}) ==
               %{fixed: 200, variable: 0, total: 200}
    end

    test "mid case: base 1000, dex 99, int 99" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 99, int: 99}) ==
               %{fixed: 200, variable: 201, total: 401}
    end

    test "no reduction when dex and int are 0" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 200, variable: 800, total: 1_000}
    end

    test "applies one varcast reduction after the sqrt step, leaving fixed cast untouched" do
      # base 1000, dex/int 0 -> fixed 200, variable 800; 45% reduction -> 800*0.55 = 440
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               statuses: %{suffragium: 45}
             }) ==
               %{fixed: 200, variable: 440, total: 640}
    end

    test "a negative Slow Cast accumulation cancels a matching Suffragium" do
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               statuses: %{slowcast: 20, suffragium: 20}
             }) == %{fixed: 200, variable: 800, total: 1_000}
    end

    test "Suffragium does not reduce a skill's explicit fixed cast" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               statuses: %{suffragium: 100}
             }) == %{fixed: 350, variable: 0, total: 350}
    end

    test "each varcast factor is capped at 100 so over-cap values do not invert the cast" do
      # 150% requested -> capped at 100% -> variable floored at 0, never negative
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               statuses: %{suffragium: 150}
             }) ==
               %{fixed: 200, variable: 0, total: 200}
    end

    test "varcast reductions default to none when absent" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 200, variable: 800, total: 1_000}
    end

    test "an item rate shortens the variable cast with binary32 rounding" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, item_global_rate: 5}) ==
               %{fixed: 200, variable: 759, total: 959}
    end

    test "positive varcast_rate lengthens the variable cast" do
      # variable 800; +25% -> 800 * 125 / 100 = 1000
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, item_global_rate: -25}) ==
               %{fixed: 200, variable: 1_000, total: 1_200}
    end

    test "varcast_rate floors the variable cast at 0, never inverting it" do
      # -150% would go negative; the 100 + rate factor floors at 0
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, item_global_rate: 150}) ==
               %{fixed: 200, variable: 0, total: 200}
    end

    test "item rate applies after the status variable reduction" do
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               statuses: %{suffragium: 50},
               item_global_rate: 50
             }) == %{fixed: 200, variable: 200, total: 400}
    end

    test "varcast_rate never touches the fixed cast" do
      assert %{fixed: 350} =
               CastTime.compute(definition([1_000], [350]), 1, %{
                 dex: 0,
                 int: 0,
                 item_global_rate: 150
               })
    end

    test "varcast_rate defaults to 0 when absent" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 200, variable: 800, total: 1_000}
    end
  end

  describe "compute/3 Renewal fixed_cast delta" do
    @describetag game_mode: :renewal

    test "a negative delta shortens the fixed cast in flat milliseconds" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_flat: -100
             }) == %{fixed: 250, variable: 1_000, total: 1_250}
    end

    test "a positive delta lengthens the fixed cast" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_flat: 150
             }) ==
               %{fixed: 500, variable: 1_000, total: 1_500}
    end

    test "the fixed cast floors at 0 and the variable portion is unaffected" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_flat: -5_000
             }) == %{fixed: 0, variable: 1_000, total: 1_000}
    end

    test "the delta also applies to the default 20% fixed portion" do
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_flat: -50
             }) ==
               %{fixed: 150, variable: 800, total: 950}
    end

    test "item fixed-cast delta defaults to zero when absent" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 350, variable: 1_000, total: 1_350}
    end
  end

  describe "compute/3 Renewal fixcast_rate" do
    @describetag game_mode: :renewal

    test "a negative rate scales the fixed cast down by a percentage" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_rate: 50
             }) == %{fixed: 175, variable: 1_000, total: 1_175}
    end

    test "a positive rate scales the fixed cast up" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               statuses: %{freezing: true}
             }) ==
               %{fixed: 525, variable: 1_000, total: 1_525}
    end

    test "the rate floors the fixed cast at 0, never inverting it" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_rate: 150
             }) == %{fixed: 0, variable: 1_000, total: 1_000}
    end

    test "the flat fixed bonus precedes its percentage rate" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_rate: 50,
               item_global_fixed_flat: -25
             }) == %{fixed: 162, variable: 1_000, total: 1_162}
    end

    test "the rate also scales the default 20% fixed portion" do
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               item_global_fixed_rate: 50
             }) ==
               %{fixed: 100, variable: 800, total: 900}
    end

    test "the rate never touches the variable cast" do
      assert %{variable: 1_000} =
               CastTime.compute(definition([1_000], [350]), 1, %{
                 dex: 0,
                 int: 0,
                 item_global_fixed_rate: 80
               })
    end

    test "item fixed rate defaults to zero when absent" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 350, variable: 1_000, total: 1_350}
    end
  end

  describe "compute/3 pre-renewal" do
    @describetag game_mode: :pre_renewal

    test "uses one DEX-scaled variable component and ignores INT" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 99, int: 999}) ==
               %{fixed: 0, variable: 340, total: 340}
    end

    test "has no stat reduction at zero DEX" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 0, variable: 1_000, total: 1_000}
    end

    test "becomes instant at or above 150 DEX" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 150, int: 0}) ==
               %{fixed: 0, variable: 0, total: 0}

      assert CastTime.compute(definition([1_000]), 1, %{dex: 200, int: 0}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "ignores a declared fixed component" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 0, variable: 1_000, total: 1_000}
    end

    test "a fixed-only definition is instant" do
      assert CastTime.compute(definition([], [500]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "ignores Renewal-only modifier channels" do
      stats = %{
        dex: 0,
        int: 0,
        statuses: %{laziness: 100},
        item_global_fixed_flat: 500,
        item_global_fixed_rate: 100
      }

      assert CastTime.compute(definition([1_000], [350]), 1, stats) ==
               %{fixed: 0, variable: 1_000, total: 1_000}
    end

    test "applies skill and early rates before the first truncation" do
      stats = %{dex: 99, int: 0, item_skill_rate: -20, item_global_rate: 25}

      assert CastTime.compute(definition([1_000]), 1, stats) ==
               %{fixed: 0, variable: 204, total: 204}
    end

    test "applies late reductions after the early-stage truncation" do
      stats = %{dex: 99, int: 0, statuses: %{suffragium: 33}}

      assert CastTime.compute(definition([1_001]), 1, stats) ==
               %{fixed: 0, variable: 227, total: 227}
    end

    test "caps each late reduction and never inverts the cast" do
      stats = %{dex: 0, int: 0, statuses: %{suffragium: 150}}

      assert CastTime.compute(definition([1_000]), 1, stats) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "an over-large early reduction floors the cast at zero" do
      stats = %{dex: 0, int: 0, item_global_rate: 150}

      assert CastTime.compute(definition([1_000]), 1, stats) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "ignore_dex preserves the full single-component cast" do
      definition = %{definition([1_000]) | ignore_dex: true}

      assert CastTime.compute(definition, 1, %{dex: 150, int: 500}) ==
               %{fixed: 0, variable: 1_000, total: 1_000}
    end
  end
end
