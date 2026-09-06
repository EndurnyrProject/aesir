defmodule Aesir.ZoneServer.Unit.Player.CombatCalculationsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Passives
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

    stub(Passives, :flee_bonus, fn _stats -> 0 end)

    test_stats
  end

  describe "accuracy modifiers" do
    test "HIT includes status, equipment and passive bonuses" do
      stats = create_test_stats()
      base_hit = CombatCalculations.calculate_hit(stats)

      stub(Stats, :get_status_modifier, fn _stats, :hit -> 10 end)
      assert CombatCalculations.calculate_hit(stats) == base_hit + 10

      stats = %{stats | modifiers: %{equipment: %{hit: 7}, passive: %{hit: 3}}}
      assert CombatCalculations.calculate_hit(stats) == base_hit + 20
    end

    test "FLEE includes status, equipment and passive bonuses" do
      stats = create_test_stats()
      base_flee = CombatCalculations.calculate_flee(stats)

      stub(Stats, :get_status_modifier, fn _stats, :flee -> 15 end)
      assert CombatCalculations.calculate_flee(stats) == base_flee + 15

      stub(Passives, :flee_bonus, fn _stats -> 20 end)
      stats = %{stats | modifiers: %{equipment: %{flee: 7}}}
      assert CombatCalculations.calculate_flee(stats) == base_flee + 42
    end
  end

  describe "calculate_perfect_dodge/1" do
    test "calculates perfect dodge in per-mille units: LUK + 10" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 50}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      assert perfect_dodge == 60
    end

    test "retains LUK precision in per-mille units" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 47}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      assert perfect_dodge == 57
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

      assert perfect_dodge == 65
    end

    test "includes the equipment modifier (bFlee2, already in per-mille units)" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 50},
          modifiers: %{equipment: %{perfect_dodge: 30}}
        })

      assert CombatCalculations.calculate_perfect_dodge(stats) == 90
    end

    test "high LUK scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 99}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      assert perfect_dodge == 109
    end

    test "low LUK scenario" do
      stats =
        create_test_stats(%{
          base_stats: %{luk: 4}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(stats)

      assert perfect_dodge == 14
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

defmodule Aesir.ZoneServer.Unit.Player.AccuracyTest do
  use ExUnit.Case,
    async: true,
    parameterize: [
      %{level: 60, dex: 80, agi: 90, luk: 60, con: 0, renewal: {335, 262}, classic: {140, 150}},
      %{level: 55, dex: 75, agi: 75, luk: 50, con: 0, renewal: {321, 240}, classic: {130, 130}},
      %{level: 55, dex: 75, agi: 75, luk: 47, con: 0, renewal: {320, 239}, classic: {130, 130}},
      %{level: 1, dex: 1, agi: 1, luk: 1, con: 0, renewal: {177, 102}, classic: {2, 2}},
      %{level: 99, dex: 120, agi: 99, luk: 80, con: 0, renewal: {420, 314}, classic: {219, 198}},
      %{level: 60, dex: 80, agi: 90, luk: 50, con: 0, renewal: {331, 260}, classic: {140, 150}},
      %{level: 85, dex: 80, agi: 99, luk: 70, con: 0, renewal: {363, 298}, classic: {165, 184}},
      %{level: 55, dex: 75, agi: 75, luk: 47, con: 7, renewal: {334, 253}, classic: {130, 130}}
    ]

  alias Aesir.ZoneServer.Unit.Player.CombatCalculations
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup context do
    stats = %Stats{
      base_stats: %BaseStats{
        dex: context.dex,
        agi: context.agi,
        luk: context.luk,
        con: context.con
      },
      progression: %PlayerProgression{base_level: context.level},
      modifiers: %Modifiers{}
    }

    {:ok, stats: stats}
  end

  @tag game_mode: :renewal
  test "Renewal applies full levels, LUK, CON and actor baselines", %{
    stats: stats,
    renewal: expected
  } do
    assert {CombatCalculations.calculate_hit(stats), CombatCalculations.calculate_flee(stats)} ==
             expected
  end

  @tag game_mode: :pre_renewal
  test "classic applies full levels without LUK, CON or actor baselines", %{
    stats: stats,
    classic: expected
  } do
    assert {CombatCalculations.calculate_hit(stats), CombatCalculations.calculate_flee(stats)} ==
             expected
  end
end
