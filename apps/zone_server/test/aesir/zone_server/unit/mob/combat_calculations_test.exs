defmodule Aesir.ZoneServer.Unit.Mob.CombatCalculationsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Unit.Mob.CombatCalculations

  defp create_test_mob(overrides) do
    default_mob = %MobDefinition{
      id: 1001,
      aegis_name: :test_mob,
      name: "Test Mob",
      level: 25,
      hp: 1000,
      stats: %{
        str: 40,
        agi: 30,
        vit: 50,
        int: 20,
        dex: 35,
        luk: 15
      },
      atk_min: 50,
      atk_max: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    Map.merge(default_mob, overrides)
  end

  describe "calculate_hit/1" do
    test "calculates hit using simplified formula: level + dex" do
      mob =
        create_test_mob(%{
          level: 30,
          stats: %{dex: 45}
        })

      hit = CombatCalculations.calculate_hit(mob)

      # 30 + 45 = 75
      assert hit == 75
    end

    test "handles low level mob" do
      mob =
        create_test_mob(%{
          level: 5,
          stats: %{dex: 10}
        })

      hit = CombatCalculations.calculate_hit(mob)

      # 5 + 10 = 15
      assert hit == 15
    end

    test "handles high level mob" do
      mob =
        create_test_mob(%{
          level: 80,
          stats: %{dex: 90}
        })

      hit = CombatCalculations.calculate_hit(mob)

      # 80 + 90 = 170
      assert hit == 170
    end

    test "boss mob scenario" do
      boss_mob =
        create_test_mob(%{
          level: 99,
          stats: %{dex: 120}
        })

      hit = CombatCalculations.calculate_hit(boss_mob)

      # 99 + 120 = 219
      assert hit == 219
    end
  end

  describe "calculate_flee/1" do
    test "calculates flee using simplified formula: level + agi" do
      mob =
        create_test_mob(%{
          level: 35,
          stats: %{agi: 55}
        })

      flee = CombatCalculations.calculate_flee(mob)

      # 35 + 55 = 90
      assert flee == 90
    end

    test "handles slow mob with low AGI" do
      slow_mob =
        create_test_mob(%{
          level: 20,
          stats: %{agi: 10}
        })

      flee = CombatCalculations.calculate_flee(slow_mob)

      # 20 + 10 = 30
      assert flee == 30
    end

    test "handles fast mob with high AGI" do
      fast_mob =
        create_test_mob(%{
          level: 40,
          stats: %{agi: 80}
        })

      flee = CombatCalculations.calculate_flee(fast_mob)

      # 40 + 80 = 120
      assert flee == 120
    end

    test "agile boss scenario" do
      agile_boss =
        create_test_mob(%{
          level: 85,
          stats: %{agi: 95}
        })

      flee = CombatCalculations.calculate_flee(agile_boss)

      # 85 + 95 = 180
      assert flee == 180
    end
  end

  describe "calculate_perfect_dodge/1" do
    test "calculates perfect dodge using formula: luk/5" do
      mob =
        create_test_mob(%{
          stats: %{luk: 50}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(mob)

      # 50/5 = 10
      assert perfect_dodge == 10
    end

    test "handles fractional values by truncating" do
      mob =
        create_test_mob(%{
          stats: %{luk: 47}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(mob)

      # 47/5 = 9 (trunc 9.4)
      assert perfect_dodge == 9
    end

    test "handles very low LUK" do
      unlucky_mob =
        create_test_mob(%{
          stats: %{luk: 3}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(unlucky_mob)

      # 3/5 = 0 (truncated)
      assert perfect_dodge == 0
    end

    test "handles high LUK boss" do
      lucky_boss =
        create_test_mob(%{
          stats: %{luk: 85}
        })

      perfect_dodge = CombatCalculations.calculate_perfect_dodge(lucky_boss)

      # 85/5 = 17
      assert perfect_dodge == 17
    end

    test "normal mob range" do
      scenarios = [
        # 25/5 = 5
        {25, 5},
        # 30/5 = 6
        {30, 6},
        # 42/5 = 8
        {42, 8},
        # 60/5 = 12
        {60, 12}
      ]

      for {luk, expected} <- scenarios do
        mob = create_test_mob(%{stats: %{luk: luk}})
        result = CombatCalculations.calculate_perfect_dodge(mob)
        assert result == expected, "Failed for LUK: #{luk}, expected: #{expected}, got: #{result}"
      end
    end
  end

  describe "calculate_aspd/1" do
    test "calculates ASPD from attack delay: max(100, 200 - attack_delay/10)" do
      mob =
        create_test_mob(%{
          attack_delay: 1000
        })

      aspd = CombatCalculations.calculate_aspd(mob)

      # max(100, 200 - 1000/10) = max(100, 100) = 100
      assert aspd == 100
    end

    test "handles fast attacking mob" do
      fast_mob =
        create_test_mob(%{
          attack_delay: 800
        })

      aspd = CombatCalculations.calculate_aspd(fast_mob)

      # max(100, 200 - 800/10) = max(100, 120) = 120
      assert aspd == 120
    end

    test "handles slow attacking mob" do
      slow_mob =
        create_test_mob(%{
          attack_delay: 2000
        })

      aspd = CombatCalculations.calculate_aspd(slow_mob)

      # max(100, 200 - 2000/10) = max(100, 0) = 100
      assert aspd == 100
    end

    test "handles very fast mob" do
      very_fast_mob =
        create_test_mob(%{
          attack_delay: 500
        })

      aspd = CombatCalculations.calculate_aspd(very_fast_mob)

      # max(100, 200 - 500/10) = max(100, 150) = 150
      assert aspd == 150
    end

    test "handles extreme attack delays" do
      scenarios = [
        # Very fast
        {200, 180},
        # Fast
        {600, 140},
        # Slow but above minimum
        {1200, 80},
        # Very slow, clamped to minimum
        {3000, 100}
      ]

      for {delay, expected} <- scenarios do
        mob = create_test_mob(%{attack_delay: delay})
        result = CombatCalculations.calculate_aspd(mob)
        assert result == max(100, expected), "Failed for delay: #{delay}"
      end
    end
  end

  describe "calculate_base_attack/1" do
    test "returns atk_min as base attack" do
      mob =
        create_test_mob(%{
          atk_min: 75,
          atk_max: 85
        })

      base_atk = CombatCalculations.calculate_base_attack(mob)

      # Uses minimum attack value
      assert base_atk == 75
    end

    test "handles weak mob" do
      weak_mob =
        create_test_mob(%{
          atk_min: 10,
          atk_max: 15
        })

      base_atk = CombatCalculations.calculate_base_attack(weak_mob)

      assert base_atk == 10
    end

    test "handles boss mob" do
      boss_mob =
        create_test_mob(%{
          atk_min: 500,
          atk_max: 600
        })

      base_atk = CombatCalculations.calculate_base_attack(boss_mob)

      assert base_atk == 500
    end

    test "various mob attack ranges" do
      scenarios = [
        # Low level mob
        {25, 35},
        # Mid level mob
        {80, 100},
        # High level mob
        {150, 180},
        # Boss level mob
        {300, 400}
      ]

      for {atk_min, atk_max} <- scenarios do
        mob = create_test_mob(%{atk_min: atk_min, atk_max: atk_max})
        result = CombatCalculations.calculate_base_attack(mob)
        assert result == atk_min
      end
    end
  end

  describe "calculate_defense/1" do
    test "returns def value directly from mob definition" do
      mob =
        create_test_mob(%{
          def: 40
        })

      defense = CombatCalculations.calculate_defense(mob)

      assert defense == 40
    end

    test "handles low defense mob" do
      squishy_mob =
        create_test_mob(%{
          def: 5
        })

      defense = CombatCalculations.calculate_defense(squishy_mob)

      assert defense == 5
    end

    test "handles high defense mob" do
      tanky_mob =
        create_test_mob(%{
          def: 200
        })

      defense = CombatCalculations.calculate_defense(tanky_mob)

      assert defense == 200
    end

    test "various defense values" do
      defense_values = [0, 15, 30, 60, 120, 250]

      for def_val <- defense_values do
        mob = create_test_mob(%{def: def_val})
        result = CombatCalculations.calculate_defense(mob)
        assert result == def_val
      end
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

    test "all callbacks work with valid mob data" do
      mob =
        create_test_mob(%{
          level: 45,
          stats: %{str: 50, agi: 40, vit: 60, int: 30, dex: 55, luk: 25},
          atk_min: 80,
          atk_max: 95,
          def: 35,
          attack_delay: 1000
        })

      assert is_integer(CombatCalculations.calculate_hit(mob))
      assert is_integer(CombatCalculations.calculate_flee(mob))
      assert is_integer(CombatCalculations.calculate_perfect_dodge(mob))
      assert is_integer(CombatCalculations.calculate_aspd(mob))
      assert is_integer(CombatCalculations.calculate_base_attack(mob))
      assert is_integer(CombatCalculations.calculate_defense(mob))
    end
  end

  describe "edge cases and boundary conditions" do
    test "handles zero stats" do
      minimal_mob =
        create_test_mob(%{
          level: 1,
          stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
          atk_min: 1,
          def: 0,
          attack_delay: 1000
        })

      # Should not crash with minimal stats
      # 1 + 0
      assert CombatCalculations.calculate_hit(minimal_mob) == 1
      # 1 + 0
      assert CombatCalculations.calculate_flee(minimal_mob) == 1
      # 0/5
      assert CombatCalculations.calculate_perfect_dodge(minimal_mob) == 0
      assert CombatCalculations.calculate_base_attack(minimal_mob) == 1
      assert CombatCalculations.calculate_defense(minimal_mob) == 0
      assert CombatCalculations.calculate_aspd(minimal_mob) == 100
    end

    test "handles maximum reasonable stats" do
      maxed_mob =
        create_test_mob(%{
          level: 200,
          stats: %{str: 255, agi: 255, vit: 255, int: 255, dex: 255, luk: 255},
          atk_min: 9999,
          def: 999,
          attack_delay: 100
        })

      # Should handle high values without overflow
      assert is_integer(CombatCalculations.calculate_hit(maxed_mob))
      assert is_integer(CombatCalculations.calculate_flee(maxed_mob))
      assert is_integer(CombatCalculations.calculate_perfect_dodge(maxed_mob))
      assert is_integer(CombatCalculations.calculate_base_attack(maxed_mob))
      assert is_integer(CombatCalculations.calculate_defense(maxed_mob))
      assert is_integer(CombatCalculations.calculate_aspd(maxed_mob))
    end
  end
end
