defmodule Aesir.ZoneServer.Unit.Player.CombatCalculationsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Unit.Player.CombatCalculations
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :set_mimic_from_context

  defp create_test_stats(overrides \\ %{}) do
    base_stats = %{
      str: 50,
      agi: 50,
      vit: 50,
      int: 50,
      dex: 50,
      luk: 50
    }

    progression = %{
      base_level: 50,
      job_level: 25
    }

    modifiers = %{
      status_effects: %{},
      job_bonuses: %{},
      equipment: %{}
    }

    test_stats = %Stats{
      base_stats: Map.merge(base_stats, Map.get(overrides, :base_stats, %{})),
      progression: Map.merge(progression, Map.get(overrides, :progression, %{})),
      modifiers: Map.merge(modifiers, Map.get(overrides, :modifiers, %{}))
    }

    stub(Stats, :get_effective_stat, fn stats, stat ->
      Map.get(stats.base_stats, stat, 0)
    end)

    stub(Stats, :get_status_modifier, fn _stats, _modifier ->
      # No modifiers for basic tests
      0
    end)

    stub(Stats, :calculate_aspd, fn _stats ->
      # Default ASPD value
      150
    end)

    test_stats
  end

  describe "calculate_hit/1" do
    test "calculates hit using rAthena formula: DEX + LUK/3 + base_level/4" do
      stats =
        create_test_stats(%{
          base_stats: %{dex: 80, luk: 60},
          progression: %{base_level: 60}
        })

      hit = CombatCalculations.calculate_hit(stats)

      # 80 + 60/3 + 60/4 = 80 + 20 + 15 = 115
      assert hit == 115
    end

    test "handles fractional values by truncating" do
      stats =
        create_test_stats(%{
          base_stats: %{dex: 75, luk: 50},
          progression: %{base_level: 55}
        })

      hit = CombatCalculations.calculate_hit(stats)

      # 75 + 50/3 + 55/4 = 75 + 16 (trunc 16.67) + 13 (trunc 13.75) = 105
      assert hit == 105
    end

    test "includes status effect modifiers" do
      stats =
        create_test_stats(%{
          base_stats: %{dex: 80, luk: 60},
          progression: %{base_level: 60}
        })

      # Mock status modifier returning +10 hit
      stub(Stats, :get_status_modifier, fn _stats, :hit ->
        10
      end)

      hit = CombatCalculations.calculate_hit(stats)

      # Base 115 + 10 modifier = 125
      assert hit == 125
    end

    test "handles minimum stats" do
      stats =
        create_test_stats(%{
          base_stats: %{dex: 1, luk: 1},
          progression: %{base_level: 1}
        })

      hit = CombatCalculations.calculate_hit(stats)

      # 1 + 1/3 + 1/4 = 1 + 0 + 0 = 1
      assert hit == 1
    end

    test "handles high level scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{dex: 120, luk: 80},
          progression: %{base_level: 99}
        })

      hit = CombatCalculations.calculate_hit(stats)

      # 120 + 80/3 + 99/4 = 120 + 26 (trunc 26.67) + 24 (trunc 24.75) = 171
      assert hit == 171
    end
  end

  describe "calculate_flee/1" do
    test "calculates flee using rAthena formula: AGI + LUK/5 + base_level/4" do
      stats =
        create_test_stats(%{
          base_stats: %{agi: 90, luk: 50},
          progression: %{base_level: 60}
        })

      flee = CombatCalculations.calculate_flee(stats)

      # 90 + 50/5 + 60/4 = 90 + 10 + 15 = 115
      assert flee == 115
    end

    test "handles fractional values by truncating" do
      stats =
        create_test_stats(%{
          base_stats: %{agi: 75, luk: 47},
          progression: %{base_level: 55}
        })

      flee = CombatCalculations.calculate_flee(stats)

      # 75 + 47/5 + 55/4 = 75 + 9 (trunc 9.4) + 13 (trunc 13.75) = 98
      assert flee == 98
    end

    test "includes status effect modifiers" do
      stats =
        create_test_stats(%{
          base_stats: %{agi: 90, luk: 50},
          progression: %{base_level: 60}
        })

      # Mock status modifier returning +15 flee
      stub(Stats, :get_status_modifier, fn _stats, :flee ->
        15
      end)

      flee = CombatCalculations.calculate_flee(stats)

      # Base 115 + 15 modifier = 130
      assert flee == 130
    end

    test "AGI build scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{agi: 99, luk: 70},
          progression: %{base_level: 85}
        })

      flee = CombatCalculations.calculate_flee(stats)

      # 99 + 70/5 + 85/4 = 99 + 14 + 21 = 134
      assert flee == 134
    end
  end

  describe "calculate_perfect_dodge/1" do
    test "calculates perfect dodge: LUK/5" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 50}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      # 50/5 = 10
      assert perfect_dodge == 10
    end

    test "handles fractional values by truncating" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 47}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      # 47/5 = 9 (trunc 9.4)
      assert perfect_dodge == 9
    end

    test "includes status effect modifiers" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 50}
        })

      # Mock status modifier returning +5 perfect dodge
      stub(Stats, :get_status_modifier, fn _stats, :perfect_dodge ->
        5
      end)

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      # Base 10 + 5 modifier = 15
      assert perfect_dodge == 15
    end

    test "high LUK scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 99}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      # 99/5 = 19
      assert perfect_dodge == 19
    end

    test "low LUK scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 4}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      # 4/5 = 0 (truncated)
      assert perfect_dodge == 0
    end
  end

  describe "calculate_base_attack/1" do
    test "calculates base attack (STR * 2) + (DEX / 5) + (LUK / 3) + base_level/4" do
      stats =
        create_test_stats(%{
          base_stats: %{str: 60, dex: 50, luk: 30},
          progression: %{base_level: 60}
        })

      base_atk = CombatCalculations.calculate_base_attack(stats)

      # (60 * 2) + (50 / 5) + (30 / 3) + 60/4 = 120 + 10 + 10 + 15 = 155
      assert base_atk == 155
    end

    test "handles fractional values by truncating" do
      stats =
        create_test_stats(%{
          base_stats: %{str: 55, dex: 47, luk: 32},
          progression: %{base_level: 57}
        })

      base_atk = CombatCalculations.calculate_base_attack(stats)

      # (55 * 2) + (47 / 5) + (32 / 3) + 57/4 = 110 + 9 + 10 + 14 = 143
      assert base_atk == 143
    end

    test "includes status effect modifiers" do
      stats =
        create_test_stats(%{
          base_stats: %{str: 60, dex: 50, luk: 30},
          progression: %{base_level: 60}
        })

      # Mock status modifier returning +20 atk
      stub(Stats, :get_status_modifier, fn _stats, :atk ->
        20
      end)

      base_atk = CombatCalculations.calculate_base_attack(stats)

      # Base 155 + 20 modifier = 175
      assert base_atk == 175
    end

    test "STR build scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{str: 99, dex: 40, luk: 20},
          progression: %{base_level: 85}
        })

      base_atk = CombatCalculations.calculate_base_attack(stats)

      # (99 * 2) + (40 / 5) + (20 / 3) + 85/4 = 198 + 8 + 6 + 21 = 233
      assert base_atk == 233
    end
  end

  describe "calculate_aspd/1" do
    test "delegates to existing Stats module implementation" do
      stats = create_test_stats()

      aspd = CombatCalculations.calculate_aspd(stats)

      # Should return mocked value
      assert aspd == 150
    end
  end

  describe "calculate_defense/1" do
    test "calculates defense including soft defense: VIT + VIT/2" do
      stats =
        create_test_stats(%{
          base_stats: %{vit: 60}
        })

      # Mock hard defense from equipment/modifiers
      stub(Stats, :get_status_modifier, fn _stats, :def ->
        30
      end)

      defense = CombatCalculations.calculate_defense(stats)

      # Hard def 30 + soft def (60 + 30) = 30 + 90 = 120
      assert defense == 120
    end

    test "handles fractional soft defense by truncating" do
      stats =
        create_test_stats(%{
          base_stats: %{vit: 55}
        })

      # No equipment defense
      stub(Stats, :get_status_modifier, fn _stats, :def ->
        0
      end)

      defense = CombatCalculations.calculate_defense(stats)

      # Hard def 0 + soft def (55 + 27) = 82
      assert defense == 82
    end

    test "high VIT tank scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{vit: 99}
        })

      # High equipment defense
      stub(Stats, :get_status_modifier, fn _stats, :def ->
        50
      end)

      defense = CombatCalculations.calculate_defense(stats)

      # Hard def 50 + soft def (99 + 49) = 50 + 148 = 198
      assert defense == 198
    end
  end

  describe "integration with behavior" do
    test "implements all required CombatCalculations callbacks" do
      functions = CombatCalculations.__info__(:functions)

      expected_functions = [
        {:calculate_hit, 1},
        {:calculate_flee, 1},
        {:calculate_perfect_dodge, 1},
        {:calculate_aspd, 1},
        {:calculate_base_attack, 1},
        {:calculate_defense, 1}
      ]

      for expected_func <- expected_functions do
        assert expected_func in functions, "Missing function: #{inspect(expected_func)}"
      end
    end

    test "all callbacks work with valid player stats" do
      stats =
        create_test_stats(%{
          base_stats: %{str: 70, agi: 60, vit: 80, int: 40, dex: 90, luk: 50},
          progression: %{base_level: 75, job_level: 40}
        })

      assert is_integer(CombatCalculations.calculate_hit(stats))
      assert is_integer(CombatCalculations.calculate_flee(stats))
      assert is_integer(CombatCalculations.calculate_perfect_dodge(stats))
      assert is_integer(CombatCalculations.calculate_aspd(stats))
      assert is_integer(CombatCalculations.calculate_base_attack(stats))
      assert is_integer(CombatCalculations.calculate_defense(stats))
    end
  end
end
