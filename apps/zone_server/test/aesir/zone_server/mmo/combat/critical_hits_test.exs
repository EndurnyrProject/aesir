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
