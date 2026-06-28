defmodule Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculatorTest do
  @moduledoc """
  Tests for the renewal magic damage calculator.

  Numbers are hand-computed against the rAthena renewal MDEF formula
  (`battle.cpp:6105`): `dmg = matk * (1000 + hardMDEF) / (1000 + 10*hardMDEF) - softMDEF`,
  floored at 1. Magic always hits and never crits.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ModifierCalculator)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :ok
  end

  defp attacker(matk) do
    %{unit_type: :player, unit_id: 1001, combat_stats: %{matk: matk}}
  end

  defp banded_attacker(min, max) do
    %{
      unit_type: :player,
      unit_id: 1001,
      combat_stats: %{matk: max, matk_min: min, matk_max: max}
    }
  end

  defp defender(hard_mdef, soft_mdef, element \\ {:neutral, 1}) do
    %{
      unit_type: :mob,
      unit_id: 2001,
      combat_stats: %{mdef: hard_mdef, soft_mdef: soft_mdef},
      element: element
    }
  end

  describe "calculate_magic_damage/3" do
    test "baseline single hit applies MDEF reduction and floors" do
      # matk 100, ratio 100, neutral vs neutral, hard 10 / soft 5:
      # 100 * 1010 / 1100 = 91.818..., - 5 = 86.818... -> trunc 86
      assert {:ok, %{damage: 86, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "skill_ratio scales the base MATK" do
      # ratio 300: skilled = 300; 300 * 1010 / 1100 = 275.454..., - 5 = 270.454... -> 270
      assert {:ok, %{damage: 270, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5),
                 skill_ratio: 300
               )
    end

    test "bonus_matk adds a flat amount after the skill ratio" do
      # skilled = div(100*100,100) + 50 = 150; 150 * 1010 / 1100 = 137.727..., - 5 = 132.727 -> 132
      assert {:ok, %{damage: 132, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5),
                 bonus_matk: 50
               )
    end

    test "fixed_damage short-circuits the whole pipeline" do
      assert {:ok, %{damage: 50, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(9999), defender(500, 500),
                 fixed_damage: 50,
                 skill_ratio: 400,
                 element: :fire
               )
    end

    test "element modifier multiplies before MDEF reduction" do
      # fire vs earth (level 1) = 2.0: skilled 100 -> 200; 200 * 1010 / 1100 = 183.636, - 5 = 178.636 -> 178
      assert {:ok, %{damage: 178, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(
                 attacker(100),
                 defender(10, 5, {:earth, 1}),
                 element: :fire
               )
    end

    test "status damage_multiplier scales damage" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{damage_multiplier: 0.5} end)

      # skilled 100, element 1.0, *1.5 = 150; 150 * 1010 / 1100 = 137.727, - 5 = 132.727 -> 132
      assert {:ok, %{damage: 132, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(10, 5))
    end

    test "hard mdef of -100 uses -99 and does not crash" do
      # effective -99: 100 * (1000-99) / (1000-990) - 0 = 100 * 901 / 10 = 9010
      assert {:ok, %{damage: 9010, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(100), defender(-100, 0))
    end

    test "damage is floored at 1 when reduction would go to zero or below" do
      # matk 1, hard 0, soft 100: 1 * 1000/1000 - 100 = -99 -> clamp 1
      assert {:ok, %{damage: 1, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(attacker(1), defender(0, 100))
    end

    test "rolls the band per call: a degenerate band (min == max) is deterministic" do
      assert {:ok, %{damage: 86, is_critical: false}} =
               MagicDamageCalculator.calculate_magic_damage(
                 banded_attacker(100, 100),
                 defender(10, 5)
               )
    end

    test "a wide band stays within its derived damage bounds across rolls" do
      # band 1..101 -> skilled in [1, 100]; 1 * 1010/1100 - 5 floors to 1,
      # 100 * 1010/1100 - 5 = 86. So every roll lands in [1, 86].
      for _ <- 1..200 do
        assert {:ok, %{damage: damage}} =
                 MagicDamageCalculator.calculate_magic_damage(
                   banded_attacker(1, 101),
                   defender(10, 5)
                 )

        assert damage >= 1 and damage <= 86
      end
    end
  end
end
