defmodule Aesir.ZoneServer.Mmo.Combat.CriticalHitsTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  doctest CriticalHits

  describe "calculate_critical_rate/1" do
    test "raw LUK uses the active natural critical basis without an implied level" do
      assert CriticalHits.calculate_critical_rate(%{luk: 30}) == mode_value(100, 110)
      assert CriticalHits.calculate_critical_rate(%{luk: 99}) == mode_value(307, 340)
      assert CriticalHits.calculate_critical_rate(%{luk: 1}) == 13
      assert CriticalHits.calculate_critical_rate(%{luk: 150}) == mode_value(460, 510)
      assert CriticalHits.calculate_critical_rate(%{luk: 300}) == mode_value(910, 1_000)
    end

    test "raw-stat fallback retains the mode-specific level term" do
      assert CriticalHits.calculate_critical_rate(%{luk: 20, base_level: 9}) == mode_value(70, 76)

      assert CriticalHits.calculate_critical_rate(%{luk: 20, base_level: 10}) ==
               mode_value(71, 76)

      assert CriticalHits.calculate_critical_rate(%{luk: 20, base_level: 99}) ==
               mode_value(79, 76)
    end

    test "caps critical rate at 1000 (100%)" do
      # High LUK values should be capped
      assert CriticalHits.calculate_critical_rate(%{luk: 400}) == 1000
      assert CriticalHits.calculate_critical_rate(%{luk: 999}) == 1000
      assert CriticalHits.calculate_critical_rate(%{luk: 1000}) == 1000
    end

    test "handles zero and negative LUK gracefully" do
      assert CriticalHits.calculate_critical_rate(%{luk: 0}) == 10
      assert CriticalHits.calculate_critical_rate(%{luk: -10}) == 10
    end

    test "works with PlayerStats struct" do
      player_stats = %PlayerStats{
        base_stats: %{luk: 50},
        progression: %{base_level: 60},
        modifiers: %{
          job_bonuses: %{luk: 5},
          equipment: %{luk: 10},
          status_effects: %{luk: 0}
        }
      }

      # Effective LUK65, with the natural basis and level term where applicable.
      result = CriticalHits.calculate_critical_rate(player_stats)
      assert result == mode_value(211, 226)
    end

    test "handles missing LUK field in map" do
      # Should default to LUK 1 when field is missing
      assert CriticalHits.calculate_critical_rate(%{str: 50}) == 13
      assert CriticalHits.calculate_critical_rate(%{}) == 13
    end

    test "uses a computed critical rate when one is supplied" do
      assert CriticalHits.calculate_critical_rate(%{critical: 600, luk: 30}) == 600
      assert CriticalHits.calculate_critical_rate(%{critical: 0, luk: 400}) == 0
      assert CriticalHits.calculate_critical_rate(%{critical: -10}) == 0
      assert CriticalHits.calculate_critical_rate(%{critical: 1_010}) == 1_000

      assert CriticalHits.calculate_critical_rate(%{combat_stats: %{critical_rate: 0}, luk: 400}) ==
               0
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

  describe "apply_critical_damage/2" do
    test "applies the renewal 1.4x factor with crate 0" do
      assert CriticalHits.apply_critical_damage(1000, %{combat_stats: %{crate: 0}}) == 1400
      assert CriticalHits.apply_critical_damage(100, %{combat_stats: %{crate: 0}}) == 140
      assert CriticalHits.apply_critical_damage(999, %{combat_stats: %{crate: 0}}) == 1398
    end

    test "scales the factor with crate" do
      assert CriticalHits.apply_critical_damage(1000, %{combat_stats: %{crate: 30}}) == 1700
    end

    test "defaults crate to 0 when the attacker has no crate slot (non-player/mob)" do
      assert CriticalHits.apply_critical_damage(1000, %{}) == 1400
      assert CriticalHits.apply_critical_damage(1000, %{combat_stats: %{}}) == 1400
    end

    test "applies bCritAtkRate as a percent step over the critical factor" do
      assert CriticalHits.apply_critical_damage(1000, %{equip_modifiers: %{crit_atk_rate: 50}}) ==
               2100

      assert CriticalHits.apply_critical_damage(1000, %{equip_modifiers: %{crit_atk_rate: -20}}) ==
               1120
    end

    test "bCritAtkRate compounds with crate instead of summing into it" do
      attacker = %{combat_stats: %{crate: 30}, equip_modifiers: %{crit_atk_rate: 20}}

      assert CriticalHits.apply_critical_damage(1000, attacker) == 2040
      refute CriticalHits.apply_critical_damage(1000, attacker) == 1700 + 200
    end

    test "defaults the equipment critical percent to 0 without the key" do
      assert CriticalHits.apply_critical_damage(1000, %{equip_modifiers: %{}}) == 1400
      assert CriticalHits.apply_critical_damage(1000, %{}) == 1400
    end

    test "handles edge cases" do
      assert CriticalHits.apply_critical_damage(0, %{}) == 0
      assert CriticalHits.apply_critical_damage(-10, %{}) == -14
    end

    test "maintains integer precision" do
      damage = 150
      critical_damage = CriticalHits.apply_critical_damage(damage, %{})
      assert is_integer(critical_damage)
      assert critical_damage == 210
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

      assert result.critical_rate == mode_value(100, 110)

      critical_damage = CriticalHits.apply_critical_damage(base_damage, stats)

      # Damage should be either base or the renewal critical factor
      assert result.damage == base_damage or result.damage == critical_damage

      # is_critical should match damage multiplier
      if result.is_critical do
        assert result.damage == critical_damage
      else
        assert result.damage == base_damage
      end
    end

    test "handles zero damage" do
      stats = %{luk: 50}
      result = CriticalHits.calculate_critical_hit(stats, 0)

      assert result.damage == 0
      assert is_boolean(result.is_critical)
      assert result.critical_rate == mode_value(160, 176)
    end

    test "works with high LUK stats" do
      # Should cap at 1000 (100% critical)
      stats = %{luk: 400}
      base_damage = 200

      result = CriticalHits.calculate_critical_hit(stats, base_damage)

      # With 100% critical rate, should always be critical
      assert result.is_critical == true
      # 200 * 1.4 (renewal factor, crate defaults to 0)
      assert result.damage == 280
      assert result.critical_rate == 1000
    end

    test "bCritAtkRate only reaches damage that actually rolled a critical" do
      base_damage = 200
      equip = %{crit_atk_rate: 50}

      always_crit = %{critical: 1_000, equip_modifiers: equip}
      never_crit = %{critical: 0, equip_modifiers: equip}

      crit_result = CriticalHits.calculate_critical_hit(always_crit, base_damage)
      assert crit_result.is_critical
      assert crit_result.damage == 420

      non_crit_result = CriticalHits.calculate_critical_hit(never_crit, base_damage)
      refute non_crit_result.is_critical
      assert non_crit_result.damage == base_damage
    end

    test "maintains consistency across multiple calls with same input" do
      stats = %{luk: 50}
      base_damage = 100

      # Generate multiple results
      results =
        Enum.map(1..50, fn _ -> CriticalHits.calculate_critical_hit(stats, base_damage) end)

      # All should have same critical rate
      critical_rates = Enum.map(results, & &1.critical_rate)
      assert Enum.all?(critical_rates, &(&1 == mode_value(160, 176)))

      # All damages should be either base or the renewal critical factor (100 * 1.4 = 140)
      damages = Enum.map(results, & &1.damage)
      assert Enum.all?(damages, &(&1 == 100 or &1 == 140))
    end
  end

  describe "integration with rAthena formulas" do
    test "matches authentic rAthena critical calculations" do
      # Test cases based on rAthena source code
      test_cases = [
        # Minimum case
        %{luk: 1, expected_rate: 13},
        # Early game
        %{luk: 30, expected_rate: mode_value(100, 110)},
        # Mid game
        %{luk: 60, expected_rate: mode_value(190, 210)},
        # High stats
        %{luk: 99, expected_rate: mode_value(307, 340)},
        # Very high
        %{luk: 150, expected_rate: mode_value(460, 510)},
        # Capped
        %{luk: 400, expected_rate: 1000}
      ]

      for %{luk: luk_val, expected_rate: expected} <- test_cases do
        actual = CriticalHits.calculate_critical_rate(%{luk: luk_val})

        assert actual == expected,
               "Expected LUK #{luk_val} to give critical rate #{expected}, got #{actual}"
      end
    end

    test "critical damage matches rAthena renewal 1.4x non-player branch" do
      # Non-player attackers (no crate slot) land on rAthena's x1.4 branch (battle.cpp:5652)
      damages = [1, 50, 100, 999, 1500]

      for damage <- damages do
        critical_damage = CriticalHits.apply_critical_damage(damage, %{})
        assert critical_damage == trunc(damage * 1.4)
      end
    end

    test "critical damage matches rAthena renewal crate-scaled player branch" do
      # battle.cpp:5648 — wd.damage * (1.4 + 0.01 * sstatus->crate)
      assert CriticalHits.apply_critical_damage(1000, %{combat_stats: %{crate: 0}}) == 1400
      assert CriticalHits.apply_critical_damage(1000, %{combat_stats: %{crate: 30}}) == 1700
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

  defp mode_value(renewal, classic) do
    if GameMode.mode() == :renewal, do: renewal, else: classic
  end
end
