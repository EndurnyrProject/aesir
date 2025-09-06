defmodule Aesir.ZoneServer.Mmo.Combat.CriticalHitsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  doctest CriticalHits

  describe "calculate_critical_rate/1" do
    test "calculates correct critical rate from LUK value using rAthena formula" do
      # LUK * 10/3 formula
      assert CriticalHits.calculate_critical_rate(%{luk: 30}) == 100
      assert CriticalHits.calculate_critical_rate(%{luk: 99}) == 330
      assert CriticalHits.calculate_critical_rate(%{luk: 1}) == 3
      assert CriticalHits.calculate_critical_rate(%{luk: 150}) == 500
    end

    test "caps critical rate at 1000 (100%)" do
      # High LUK values should be capped
      assert CriticalHits.calculate_critical_rate(%{luk: 300}) == 1000
      assert CriticalHits.calculate_critical_rate(%{luk: 999}) == 1000
      assert CriticalHits.calculate_critical_rate(%{luk: 1000}) == 1000
    end

    test "handles zero and negative LUK gracefully" do
      assert CriticalHits.calculate_critical_rate(%{luk: 0}) == 0
      # Note: negative LUK shouldn't happen in practice but our formula handles it
      assert CriticalHits.calculate_critical_rate(%{luk: -10}) == 0
    end

    test "works with PlayerStats struct" do
      # Create a mock PlayerStats with effective_stat function
      player_stats = %PlayerStats{
        base_stats: %{luk: 50},
        modifiers: %{
          job_bonuses: %{luk: 5},
          equipment: %{luk: 10},
          status_effects: %{luk: 0}
        }
      }

      # Should use effective LUK (50 + 5 + 10 = 65)
      # 65 * 10/3 = 216.67 -> 216
      result = CriticalHits.calculate_critical_rate(player_stats)
      assert result == 216
    end

    test "handles missing LUK field in map" do
      # Should default to LUK 1 when field is missing
      assert CriticalHits.calculate_critical_rate(%{str: 50}) == 3
      assert CriticalHits.calculate_critical_rate(%{}) == 3
    end
  end

  describe "calculate_critical_rate_from_luk/1" do
    test "calculates rate directly from LUK value" do
      assert CriticalHits.calculate_critical_rate_from_luk(30) == 100
      assert CriticalHits.calculate_critical_rate_from_luk(99) == 330
      assert CriticalHits.calculate_critical_rate_from_luk(1) == 3
    end

    test "caps at 1000 for high LUK values" do
      assert CriticalHits.calculate_critical_rate_from_luk(300) == 1000
      assert CriticalHits.calculate_critical_rate_from_luk(999) == 1000
    end

    test "handles edge cases" do
      assert CriticalHits.calculate_critical_rate_from_luk(0) == 0
      assert CriticalHits.calculate_critical_rate_from_luk(-5) == 0
    end
  end

  describe "is_critical_hit?/1" do
    test "returns false for 0% critical rate" do
      # With 0 critical rate, should never be critical
      results = Enum.map(1..100, fn _ -> CriticalHits.is_critical_hit?(0) end)
      assert Enum.all?(results, &(&1 == false))
    end

    test "returns true for 100% critical rate" do
      # With 1000 critical rate (100%), should always be critical
      results = Enum.map(1..100, fn _ -> CriticalHits.is_critical_hit?(1000) end)
      assert Enum.all?(results, &(&1 == true))
    end

    test "returns boolean for valid rates" do
      # Test with various rates - should return boolean values
      rates = [1, 100, 500, 999]

      for rate <- rates do
        results = Enum.map(1..50, fn _ -> CriticalHits.is_critical_hit?(rate) end)
        assert Enum.all?(results, &is_boolean/1)
      end
    end

    test "has appropriate probability distribution" do
      # Test that 50% critical rate gives roughly 50% critical hits
      # 50%
      critical_rate = 500
      sample_size = 1000

      results = Enum.map(1..sample_size, fn _ -> CriticalHits.is_critical_hit?(critical_rate) end)
      critical_count = Enum.count(results, & &1)
      critical_percentage = critical_count / sample_size * 100

      # Should be roughly 50% ±10% due to randomness
      assert critical_percentage >= 40.0
      assert critical_percentage <= 60.0
    end
  end

  describe "apply_critical_damage/1" do
    test "doubles damage for critical hits" do
      assert CriticalHits.apply_critical_damage(100) == 200
      assert CriticalHits.apply_critical_damage(1) == 2
      assert CriticalHits.apply_critical_damage(999) == 1998
    end

    test "handles edge cases" do
      assert CriticalHits.apply_critical_damage(0) == 0
      assert CriticalHits.apply_critical_damage(-10) == -20
    end

    test "maintains integer precision" do
      damage = 150
      critical_damage = CriticalHits.apply_critical_damage(damage)
      assert is_integer(critical_damage)
      assert critical_damage == 300
    end
  end

  describe "calculate_critical_hit/2" do
    test "returns complete critical result map" do
      # 100 critical rate (10%)
      stats = %{luk: 30}
      base_damage = 150

      result = CriticalHits.calculate_critical_hit(stats, base_damage)

      # Should contain all required fields
      assert Map.has_key?(result, :is_critical)
      assert Map.has_key?(result, :damage)
      assert Map.has_key?(result, :critical_rate)

      # Critical rate should be correct
      assert result.critical_rate == 100

      # Damage should be either base or doubled
      assert result.damage == base_damage or result.damage == base_damage * 2

      # is_critical should match damage multiplier
      if result.is_critical do
        assert result.damage == base_damage * 2
      else
        assert result.damage == base_damage
      end
    end

    test "handles zero damage" do
      stats = %{luk: 50}
      result = CriticalHits.calculate_critical_hit(stats, 0)

      assert result.damage == 0
      assert is_boolean(result.is_critical)
      assert result.critical_rate == 166
    end

    test "works with high LUK stats" do
      # Should cap at 1000 (100% critical)
      stats = %{luk: 300}
      base_damage = 200

      result = CriticalHits.calculate_critical_hit(stats, base_damage)

      # With 100% critical rate, should always be critical
      assert result.is_critical == true
      # 200 * 2
      assert result.damage == 400
      assert result.critical_rate == 1000
    end

    test "maintains consistency across multiple calls with same input" do
      stats = %{luk: 50}
      base_damage = 100

      # Generate multiple results
      results =
        Enum.map(1..50, fn _ -> CriticalHits.calculate_critical_hit(stats, base_damage) end)

      # All should have same critical rate
      critical_rates = Enum.map(results, & &1.critical_rate)
      assert Enum.all?(critical_rates, &(&1 == 166))

      # All damages should be either 100 or 200
      damages = Enum.map(results, & &1.damage)
      assert Enum.all?(damages, &(&1 == 100 or &1 == 200))
    end
  end

  describe "supports_critical?/1" do
    test "returns true for valid stat maps" do
      assert CriticalHits.supports_critical?(%{luk: 50})
      assert CriticalHits.supports_critical?(%{luk: 0})
      # Edge case but supported
      assert CriticalHits.supports_critical?(%{luk: -5})
    end

    test "returns true for PlayerStats structs" do
      player_stats = %PlayerStats{}
      assert CriticalHits.supports_critical?(player_stats)
    end

    test "returns false for invalid inputs" do
      assert CriticalHits.supports_critical?(%{str: 50}) == false
      assert CriticalHits.supports_critical?(%{}) == false
      assert CriticalHits.supports_critical?(nil) == false
      assert CriticalHits.supports_critical?("invalid") == false
    end
  end

  describe "get_critical_info/1" do
    test "returns formatted critical information" do
      # 100 critical rate = 10%
      stats = %{luk: 30}

      info = CriticalHits.get_critical_info(stats)

      assert info.critical_rate == 100
      assert info.critical_percentage == 10.0
      assert info.max_critical_rate == 1000
      assert info.max_critical_percentage == 100.0
    end

    test "handles edge cases" do
      # Zero LUK
      zero_info = CriticalHits.get_critical_info(%{luk: 0})
      assert zero_info.critical_percentage == 0.0

      # Max LUK (capped)
      max_info = CriticalHits.get_critical_info(%{luk: 999})
      assert max_info.critical_percentage == 100.0
    end

    test "works with PlayerStats" do
      player_stats = %PlayerStats{
        base_stats: %{luk: 60},
        modifiers: %{
          job_bonuses: %{luk: 10},
          equipment: %{luk: 0},
          status_effects: %{luk: 0}
        }
      }

      info = CriticalHits.get_critical_info(player_stats)

      # Effective LUK should be 70, so critical rate = 70 * 10/3 = 233
      assert info.critical_rate == 233
      assert abs(info.critical_percentage - 23.3) < 0.1
    end
  end

  describe "integration with rAthena formulas" do
    test "matches authentic rAthena critical calculations" do
      # Test cases based on rAthena source code
      test_cases = [
        # Minimum case
        %{luk: 1, expected_rate: 3},
        # Early game
        %{luk: 30, expected_rate: 100},
        # Mid game
        %{luk: 60, expected_rate: 200},
        # High stats
        %{luk: 99, expected_rate: 330},
        # Very high
        %{luk: 150, expected_rate: 500},
        # Capped
        %{luk: 300, expected_rate: 1000}
      ]

      for %{luk: luk_val, expected_rate: expected} <- test_cases do
        actual = CriticalHits.calculate_critical_rate(%{luk: luk_val})

        assert actual == expected,
               "Expected LUK #{luk_val} to give critical rate #{expected}, got #{actual}"
      end
    end

    test "critical damage matches rAthena 2x multiplier" do
      # rAthena always applies 2x damage for critical hits
      damages = [1, 50, 100, 999, 1500]

      for damage <- damages do
        critical_damage = CriticalHits.apply_critical_damage(damage)
        assert critical_damage == damage * 2
      end
    end

    test "random distribution uses correct range" do
      # rAthena uses rand(1000) < critical_rate
      # Our implementation should match this behavior

      # Test edge case where critical_rate = 1 (should very rarely be critical)
      critical_count =
        1..1000
        |> Enum.map(fn _ -> CriticalHits.is_critical_hit?(1) end)
        |> Enum.count(& &1)

      # With rate 1, should get approximately 1 critical hit per 1000 attempts
      # Allow some variance due to randomness
      assert critical_count >= 0
      assert critical_count <= 5
    end
  end
end
