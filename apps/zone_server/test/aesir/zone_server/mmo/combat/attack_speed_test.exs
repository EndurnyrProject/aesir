defmodule Aesir.ZoneServer.Mmo.Combat.AttackSpeedTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed

  describe "calculate_delay/1" do
    test "calculates correct delay for ASPD 150" do
      # ASPD 150 should give (200 - 150) * 10 = 500ms delay
      assert AttackSpeed.calculate_delay(150) == 500
    end

    test "calculates correct delay for maximum ASPD 193" do
      # Maximum ASPD should give (200 - 193) * 10 = 70ms delay
      assert AttackSpeed.calculate_delay(193) == 70
    end

    test "calculates correct delay for minimum ASPD 0" do
      # Minimum ASPD should give (200 - 0) * 10 = 2000ms delay
      assert AttackSpeed.calculate_delay(0) == 2000
    end

    test "calculates correct delay for mid-range ASPD 100" do
      # ASPD 100 should give (200 - 100) * 10 = 1000ms delay
      assert AttackSpeed.calculate_delay(100) == 1000
    end

    test "caps ASPD above 193 to maximum" do
      # Should treat ASPD > 193 as 193
      assert AttackSpeed.calculate_delay(200) == 70
      assert AttackSpeed.calculate_delay(999) == 70
    end

    test "caps ASPD below 0 to minimum" do
      # Should treat ASPD < 0 as 0
      assert AttackSpeed.calculate_delay(-10) == 2000
      assert AttackSpeed.calculate_delay(-999) == 2000
    end
  end

  describe "calculate_delay_from_stats/1" do
    test "extracts ASPD from stats and calculates delay" do
      stats = %{
        derived_stats: %{
          aspd: 160
        }
      }

      expected_delay = (200 - 160) * 10
      assert AttackSpeed.calculate_delay_from_stats(stats) == expected_delay
    end

    test "handles maximum ASPD in stats" do
      stats = %{
        derived_stats: %{
          aspd: 193
        }
      }

      assert AttackSpeed.calculate_delay_from_stats(stats) == 70
    end
  end

  describe "can_attack?/2" do
    test "allows attack when enough time has passed" do
      # Set last attack to 1 second ago
      last_attack = System.monotonic_time(:millisecond) - 1000
      # 500ms required delay
      attack_delay = 500

      assert AttackSpeed.can_attack?(last_attack, attack_delay) == true
    end

    test "prevents attack when not enough time has passed" do
      # Set last attack to 100ms ago
      last_attack = System.monotonic_time(:millisecond) - 100
      # 500ms required delay
      attack_delay = 500

      assert AttackSpeed.can_attack?(last_attack, attack_delay) == false
    end

    test "allows attack when exactly enough time has passed" do
      # Set last attack to exactly the required delay ago
      attack_delay = 500
      last_attack = System.monotonic_time(:millisecond) - attack_delay

      # Give a tiny bit of time for the function to execute
      :timer.sleep(1)
      assert AttackSpeed.can_attack?(last_attack, attack_delay) == true
    end

    test "allows first attack when last_attack_timestamp is 0" do
      assert AttackSpeed.can_attack?(0, 500) == true
    end

    test "handles very fast ASPD correctly" do
      # Fast ASPD with small delay
      last_attack = System.monotonic_time(:millisecond) - 100
      # Max ASPD delay
      attack_delay = 70

      assert AttackSpeed.can_attack?(last_attack, attack_delay) == true
    end

    test "handles very slow ASPD correctly" do
      # Slow ASPD with large delay
      last_attack = System.monotonic_time(:millisecond) - 1500
      # Min ASPD delay
      attack_delay = 2000

      assert AttackSpeed.can_attack?(last_attack, attack_delay) == false
    end
  end

  describe "current_timestamp/0" do
    test "returns current monotonic timestamp" do
      timestamp1 = AttackSpeed.current_timestamp()
      :timer.sleep(1)
      timestamp2 = AttackSpeed.current_timestamp()

      assert is_integer(timestamp1)
      assert is_integer(timestamp2)
      assert timestamp2 > timestamp1
    end

    test "timestamp is in milliseconds" do
      timestamp = AttackSpeed.current_timestamp()

      # Should be an integer (monotonic time can be negative)
      assert is_integer(timestamp)

      # Should change over time
      :timer.sleep(1)
      timestamp2 = AttackSpeed.current_timestamp()
      assert timestamp2 > timestamp
    end
  end

  describe "integration with common ASPD values" do
    test "novice barehand ASPD ~156 gives reasonable delay" do
      delay = AttackSpeed.calculate_delay(156)
      # Should be around 440ms delay
      assert delay == 440
      assert delay > 400
      assert delay < 500
    end

    test "high-level character ASPD ~180 gives fast delay" do
      delay = AttackSpeed.calculate_delay(180)
      # Should be 200ms delay
      assert delay == 200
      assert delay < 300
    end

    test "slow weapon ASPD ~120 gives slow delay" do
      delay = AttackSpeed.calculate_delay(120)
      # Should be 800ms delay
      assert delay == 800
      assert delay > 700
    end
  end

  describe "edge cases and error conditions" do
    test "handles concurrent timestamp calls" do
      # Test that multiple rapid calls work correctly
      timestamps = Enum.map(1..10, fn _ -> AttackSpeed.current_timestamp() end)

      # All should be integers
      assert Enum.all?(timestamps, &is_integer/1)

      # Should be in ascending order (allowing for same values due to speed)
      sorted_timestamps = Enum.sort(timestamps)
      assert timestamps == sorted_timestamps or length(Enum.uniq(timestamps)) == 1
    end

    test "handles extreme delay values" do
      # Very large attack delay
      large_delay = 10_000
      recent_attack = System.monotonic_time(:millisecond) - 1000

      assert AttackSpeed.can_attack?(recent_attack, large_delay) == false

      # Very small attack delay
      small_delay = 1
      old_attack = System.monotonic_time(:millisecond) - 100

      assert AttackSpeed.can_attack?(old_attack, small_delay) == true
    end
  end
end
