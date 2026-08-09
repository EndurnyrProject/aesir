defmodule Aesir.ZoneServer.Mmo.Skill.CastTimeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  defp definition(cast_time, fixed_cast_time \\ []) do
    %Definition{
      id: 83,
      name: :test_skill,
      display_name: "Test Skill",
      max_level: 10,
      cast_time: cast_time,
      fixed_cast_time: fixed_cast_time
    }
  end

  describe "compute/3" do
    test "instant when the base cast time is 0" do
      assert CastTime.compute(definition([0]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "instant when the cast_time list is empty for the level" do
      assert CastTime.compute(definition([]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "uses an explicit fixed cast when the variable cast list is empty" do
      assert CastTime.compute(definition([], [500]), 1, %{dex: 50, int: 50}) ==
               %{fixed: 500, variable: 0, total: 500}
    end

    test "fixed cast defaults to 20% of base when no fixed_cast_time is set" do
      assert %{fixed: 200} = CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0})
    end

    test "explicit fixed_cast_time overrides the 20% default" do
      assert %{fixed: 350} =
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

    test "reads the per-level cast time array" do
      assert %{total: total} =
               CastTime.compute(definition([1_000, 2_000, 3_000]), 3, %{dex: 0, int: 0})

      assert total == 3_000
    end

    test "applies one varcast reduction after the sqrt step, leaving fixed cast untouched" do
      # base 1000, dex/int 0 -> fixed 200, variable 800; 45% reduction -> 800*0.55 = 440
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, varcast_reductions: [45]}) ==
               %{fixed: 200, variable: 440, total: 640}
    end

    test "composes multiple varcast reductions multiplicatively over the variable cast" do
      # two 20% factors: 800 * 0.8 * 0.8 = 512 (NOT 800 * (1 - 0.40) = 480)
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               varcast_reductions: [20, 20]
             }) == %{fixed: 200, variable: 512, total: 712}
    end

    test "varcast reduction does not reduce a skill's fixed cast" do
      # explicit fixed 350; full 100% varcast reduction zeroes only the variable part
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               varcast_reductions: [100]
             }) == %{fixed: 350, variable: 0, total: 350}
    end

    test "each varcast factor is capped at 100 so over-cap values do not invert the cast" do
      # 150% requested -> capped at 100% -> variable floored at 0, never negative
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, varcast_reductions: [150]}) ==
               %{fixed: 200, variable: 0, total: 200}
    end

    test "varcast reductions default to none when absent" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 200, variable: 800, total: 1_000}
    end

    test "negative varcast_rate shortens the variable cast additively" do
      # base 1000, dex/int 0 -> variable 800; -5% -> 800 * 95 / 100 = 760
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, varcast_rate: -5}) ==
               %{fixed: 200, variable: 760, total: 960}
    end

    test "positive varcast_rate lengthens the variable cast" do
      # variable 800; +25% -> 800 * 125 / 100 = 1000
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, varcast_rate: 25}) ==
               %{fixed: 200, variable: 1_000, total: 1_200}
    end

    test "varcast_rate floors the variable cast at 0, never inverting it" do
      # -150% would go negative; the 100 + rate factor floors at 0
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, varcast_rate: -150}) ==
               %{fixed: 200, variable: 0, total: 200}
    end

    test "varcast_rate applies after the multiplicative varcast_reductions factor" do
      # variable 800; 50% reduction -> 400; then -50% additive -> 400 * 50/100 = 200
      assert CastTime.compute(definition([1_000]), 1, %{
               dex: 0,
               int: 0,
               varcast_reductions: [50],
               varcast_rate: -50
             }) == %{fixed: 200, variable: 200, total: 400}
    end

    test "varcast_rate never touches the fixed cast" do
      assert %{fixed: 350} =
               CastTime.compute(definition([1_000], [350]), 1, %{
                 dex: 0,
                 int: 0,
                 varcast_rate: -150
               })
    end

    test "varcast_rate defaults to 0 when absent" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 200, variable: 800, total: 1_000}
    end
  end

  describe "compute/3 fixed_cast delta" do
    test "a negative delta shortens the fixed cast in flat milliseconds" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               fixed_cast: -100
             }) == %{fixed: 250, variable: 650, total: 900}
    end

    test "a positive delta lengthens the fixed cast" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0, fixed_cast: 150}) ==
               %{fixed: 500, variable: 650, total: 1_150}
    end

    test "the fixed cast floors at 0 and the variable portion is unaffected" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               fixed_cast: -5_000
             }) == %{fixed: 0, variable: 650, total: 650}
    end

    test "the delta also applies to the default 20% fixed portion" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, fixed_cast: -50}) ==
               %{fixed: 150, variable: 800, total: 950}
    end

    test "an instant skill stays instant" do
      assert CastTime.compute(definition([0]), 1, %{dex: 0, int: 0, fixed_cast: 500}) ==
               %{fixed: 0, variable: 0, total: 0}
    end

    test "fixed_cast defaults to 0 when absent" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 350, variable: 650, total: 1_000}
    end
  end

  describe "compute/3 fixcast_rate" do
    test "a negative rate scales the fixed cast down by a percentage" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               fixcast_rate: -50
             }) == %{fixed: 175, variable: 650, total: 825}
    end

    test "a positive rate scales the fixed cast up" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0, fixcast_rate: 100}) ==
               %{fixed: 700, variable: 650, total: 1_350}
    end

    test "the rate floors the fixed cast at 0, never inverting it" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               fixcast_rate: -150
             }) == %{fixed: 0, variable: 650, total: 650}
    end

    test "the percentage rate applies before the flat fixed_cast delta" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{
               dex: 0,
               int: 0,
               fixcast_rate: -50,
               fixed_cast: -25
             }) == %{fixed: 150, variable: 650, total: 800}
    end

    test "the rate also scales the default 20% fixed portion" do
      assert CastTime.compute(definition([1_000]), 1, %{dex: 0, int: 0, fixcast_rate: -50}) ==
               %{fixed: 100, variable: 800, total: 900}
    end

    test "the rate never touches the variable cast" do
      assert %{variable: 650} =
               CastTime.compute(definition([1_000], [350]), 1, %{
                 dex: 0,
                 int: 0,
                 fixcast_rate: -80
               })
    end

    test "fixcast_rate defaults to 0 when absent" do
      assert CastTime.compute(definition([1_000], [350]), 1, %{dex: 0, int: 0}) ==
               %{fixed: 350, variable: 650, total: 1_000}
    end
  end
end
