defmodule Aesir.ZoneServer.Mmo.Combat.HitCalculationsTest do
  @moduledoc """
  Tests for hit/miss calculations in combat.
  """

  use ExUnit.Case, async: true
  doctest Aesir.ZoneServer.Mmo.Combat.HitCalculations

  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations

  describe "calculate_hit_result/2" do
    test "returns hit when perfect dodge is 0 and hit rate is high" do
      attacker = %{hit: 120, char_id: 1}
      target = %{flee: 80, perfect_dodge: 0, unit_id: 2}

      # With hit 120, flee 80, hit rate = 80 + 120 - 80 = 120 (clamped to 100)
      # Should always hit with 100% hit rate and 0 perfect dodge
      result = HitCalculations.calculate_hit_result(attacker, target)
      assert result == :hit
    end

    test "returns miss when hit rate is very low" do
      attacker = %{hit: 50, char_id: 1}
      target = %{flee: 200, perfect_dodge: 0, unit_id: 2}

      # With hit 50, flee 200, hit rate = 80 + 50 - 200 = -70 (clamped to 0)
      # Should always miss with 0% hit rate
      result = HitCalculations.calculate_hit_result(attacker, target)
      assert result == :miss
    end

    test "returns perfect_dodge when perfect dodge triggers" do
      attacker = %{hit: 120, char_id: 1}
      target = %{flee: 80, perfect_dodge: 1000, unit_id: 2}

      # With perfect_dodge 1000, should always trigger (rand(1000) < 1000 is always true)
      result = HitCalculations.calculate_hit_result(attacker, target)
      assert result == :perfect_dodge
    end

    test "perfect dodge takes priority over hit calculations" do
      # Even with impossible hit conditions, perfect dodge should trigger first
      attacker = %{hit: 999, char_id: 1}
      target = %{flee: 0, perfect_dodge: 1000, unit_id: 2}

      result = HitCalculations.calculate_hit_result(attacker, target)
      assert result == :perfect_dodge
    end

    test "handles balanced hit/flee scenarios" do
      attacker = %{hit: 100, char_id: 1}
      target = %{flee: 100, perfect_dodge: 0, unit_id: 2}

      # hit rate = 80 + 100 - 100 = 80%
      # Run multiple times to get statistical distribution
      results =
        for _ <- 1..100 do
          HitCalculations.calculate_hit_result(attacker, target)
        end

      # Should have both hits and misses in a large sample
      unique_results = results |> Enum.uniq() |> Enum.sort()
      assert :hit in unique_results
      assert :miss in unique_results
      refute :perfect_dodge in unique_results

      # Roughly 80% should be hits (allowing for random variance)
      hit_count = Enum.count(results, &(&1 == :hit))
      # Allow reasonable variance
      assert hit_count >= 60
      assert hit_count <= 95
    end
  end

  describe "calculate_hit_rate/2" do
    test "calculates basic hit rate formula" do
      attacker = %{hit: 120}
      target = %{flee: 100}

      # 80 + 120 - 100 = 100
      assert HitCalculations.calculate_hit_rate(attacker, target) == 100
    end

    test "clamps hit rate to maximum 100" do
      attacker = %{hit: 200}
      target = %{flee: 50}

      # 80 + 200 - 50 = 230, should clamp to 100
      assert HitCalculations.calculate_hit_rate(attacker, target) == 100
    end

    test "clamps hit rate to minimum 0" do
      attacker = %{hit: 50}
      target = %{flee: 200}

      # 80 + 50 - 200 = -70, should clamp to 0
      assert HitCalculations.calculate_hit_rate(attacker, target) == 0
    end

    test "calculates edge cases correctly" do
      # Equal hit and flee
      attacker = %{hit: 100}
      target = %{flee: 100}
      # 80 + 100 - 100 = 80
      assert HitCalculations.calculate_hit_rate(attacker, target) == 80

      # Very low stats
      attacker = %{hit: 1}
      target = %{flee: 1}
      # 80 + 1 - 1 = 80
      assert HitCalculations.calculate_hit_rate(attacker, target) == 80

      # Zero stats
      attacker = %{hit: 0}
      target = %{flee: 0}
      # 80 + 0 - 0 = 80
      assert HitCalculations.calculate_hit_rate(attacker, target) == 80
    end

    test "calculates various scenarios correctly" do
      test_cases = [
        # 80 + 90 - 110 = 60
        {%{hit: 90}, %{flee: 110}, 60},
        # 80 + 150 - 80 = 150 -> 100 (clamped)
        {%{hit: 150}, %{flee: 80}, 100},
        # 80 + 60 - 150 = -10 -> 0 (clamped)
        {%{hit: 60}, %{flee: 150}, 0},
        # 80 + 120 - 120 = 80
        {%{hit: 120}, %{flee: 120}, 80},
        # 80 + 200 - 200 = 80
        {%{hit: 200}, %{flee: 200}, 80}
      ]

      for {attacker, target, expected} <- test_cases do
        result = HitCalculations.calculate_hit_rate(attacker, target)

        assert result == expected,
               "Expected #{expected} for hit: #{attacker.hit}, flee: #{target.flee}, got: #{result}"
      end
    end
  end

  describe "perfect_dodge_triggered?/1" do
    test "never triggers with perfect_dodge 0" do
      target = %{perfect_dodge: 0}

      # Run multiple times to ensure it never triggers
      results =
        for _ <- 1..100 do
          HitCalculations.perfect_dodge_triggered?(target)
        end

      assert Enum.all?(results, &(&1 == false))
    end

    test "always triggers with perfect_dodge 1000" do
      target = %{perfect_dodge: 1000}

      # Should always trigger since rand(1000) < 1000 is always true
      results =
        for _ <- 1..20 do
          HitCalculations.perfect_dodge_triggered?(target)
        end

      assert Enum.all?(results, &(&1 == true))
    end

    test "never triggers with negative perfect_dodge" do
      target = %{perfect_dodge: -10}

      # Should never trigger with negative values
      results =
        for _ <- 1..50 do
          HitCalculations.perfect_dodge_triggered?(target)
        end

      assert Enum.all?(results, &(&1 == false))
    end

    test "triggers probabilistically with medium perfect_dodge" do
      # 50% chance
      target = %{perfect_dodge: 500}

      # Run many times to get statistical distribution
      results =
        for _ <- 1..200 do
          HitCalculations.perfect_dodge_triggered?(target)
        end

      # Should have both true and false results
      unique_results = results |> Enum.uniq() |> Enum.sort()
      assert true in unique_results
      assert false in unique_results

      # Roughly 50% should be true (allowing for random variance)
      true_count = Enum.count(results, &(&1 == true))
      # Allow reasonable variance around 100
      assert true_count >= 75
      assert true_count <= 125
    end

    test "handles low perfect_dodge values" do
      # 1% chance
      target = %{perfect_dodge: 10}

      # Run many times - should mostly be false with occasional true
      results =
        for _ <- 1..1000 do
          HitCalculations.perfect_dodge_triggered?(target)
        end

      # Should have both results but mostly false
      assert true in results
      assert false in results

      true_count = Enum.count(results, &(&1 == true))
      # Should be roughly 1% (10 out of 1000), but allow variance
      assert true_count >= 0
      # Allow generous variance for randomness
      assert true_count <= 30
    end

    test "handles edge case perfect_dodge values" do
      # Test value 1 (very low chance)
      target = %{perfect_dodge: 1}

      results =
        for _ <- 1..1000 do
          HitCalculations.perfect_dodge_triggered?(target)
        end

      # Should have at least some false results
      assert false in results

      # Test value 999 (very high chance)
      target = %{perfect_dodge: 999}

      results =
        for _ <- 1..100 do
          HitCalculations.perfect_dodge_triggered?(target)
        end

      # Should have at least some true results
      assert true in results
    end
  end

  describe "integration scenarios" do
    test "realistic combat scenarios" do
      # Novice vs Novice
      novice_attacker = %{hit: 95, char_id: 1}
      novice_target = %{flee: 90, perfect_dodge: 5, unit_id: 2}

      # Should mostly hit with occasional misses and very rare perfect dodges
      results =
        for _ <- 1..100 do
          HitCalculations.calculate_hit_result(novice_attacker, novice_target)
        end

      assert :hit in results
      # hit rate = 80 + 95 - 90 = 85%, should be mostly hits

      # High level vs High level
      expert_attacker = %{hit: 150, char_id: 3}
      expert_target = %{flee: 140, perfect_dodge: 20, unit_id: 4}

      results =
        for _ <- 1..100 do
          HitCalculations.calculate_hit_result(expert_attacker, expert_target)
        end

      # hit rate = 80 + 150 - 140 = 90%, should be mostly hits
      assert :hit in results

      # Tank vs DPS (high flee vs high hit)
      dps_attacker = %{hit: 180, char_id: 5}
      tank_target = %{flee: 160, perfect_dodge: 30, unit_id: 6}

      results =
        for _ <- 1..100 do
          HitCalculations.calculate_hit_result(dps_attacker, tank_target)
        end

      # hit rate = 80 + 180 - 160 = 100%, should be all hits except perfect dodges
      unique_results = results |> Enum.uniq() |> Enum.sort()
      assert :hit in unique_results
      # May have some perfect dodges due to 3% chance
    end

    test "extreme scenarios" do
      # Impossible to hit (except perfect dodge doesn't apply to attacker)
      weak_attacker = %{hit: 10, char_id: 1}
      dodge_master = %{flee: 300, perfect_dodge: 200, unit_id: 2}

      results =
        for _ <- 1..50 do
          HitCalculations.calculate_hit_result(weak_attacker, dodge_master)
        end

      # Should be mostly perfect dodges and misses, no hits
      # hit rate = 80 + 10 - 300 = -210 -> 0%
      refute :hit in results
      assert :perfect_dodge in results

      # Guaranteed hit scenario (ignoring perfect dodge)
      master_attacker = %{hit: 300, char_id: 3}
      sitting_duck = %{flee: 10, perfect_dodge: 0, unit_id: 4}

      results =
        for _ <- 1..50 do
          HitCalculations.calculate_hit_result(master_attacker, sitting_duck)
        end

      # Should be all hits
      # hit rate = 80 + 300 - 10 = 370 -> 100%
      assert Enum.all?(results, &(&1 == :hit))
    end
  end
end
