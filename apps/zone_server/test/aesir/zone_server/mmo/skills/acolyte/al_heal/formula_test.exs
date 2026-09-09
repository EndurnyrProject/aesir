defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal.FormulaTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal.Formula

  # base level 60 + INT 40 at skill level 10, with a 150-point MATK roll.
  @inputs %{
    base_level: 60,
    int: 40,
    level: 10,
    matk_roll: 150,
    heal_power: 0,
    hplus: 0,
    offensive?: false
  }

  describe "calculate/2" do
    test "renewal adds the MATK band on top of the level-and-INT base" do
      # (60 + 40) / 5 * 30 * 10 / 10 = 600, plus the 150 roll.
      assert Formula.calculate(:renewal, @inputs) == 750
    end

    test "pre-renewal uses the classic base and excludes the MATK band" do
      # (60 + 40) / 8 * (4 + 10 * 8) = 12 * 84 = 1008, with no MATK term.
      assert Formula.calculate(:pre_renewal, @inputs) == 1008
    end

    test "pre-renewal ignores the MATK roll entirely" do
      assert Formula.calculate(:pre_renewal, %{@inputs | matk_roll: 0}) ==
               Formula.calculate(:pre_renewal, @inputs)
    end

    test "an offensive cast halves the base before the MATK band is added" do
      inputs = %{@inputs | offensive?: true}

      assert Formula.calculate(:renewal, inputs) == 450
      assert Formula.calculate(:pre_renewal, inputs) == 504
    end

    test "heal power is a percentage of the base, applied before the MATK band" do
      inputs = %{@inputs | heal_power: 20}

      assert Formula.calculate(:renewal, inputs) == 870
      assert Formula.calculate(:pre_renewal, inputs) == 1209
    end

    test "the trait heal bonus is renewal-only and lands on the final amount" do
      inputs = %{@inputs | hplus: 10}

      assert Formula.calculate(:renewal, inputs) == 825
      assert Formula.calculate(:pre_renewal, inputs) == 1008
    end

    test "a renewal heal never lands below one point" do
      inputs = %{@inputs | base_level: 1, int: 0, level: 1, matk_roll: 0}

      assert Formula.calculate(:renewal, inputs) == 1
    end
  end
end
