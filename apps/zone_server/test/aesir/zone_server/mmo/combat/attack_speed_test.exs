defmodule Aesir.ZoneServer.Mmo.Combat.AttackSpeedTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed

  describe "calculate_delay/1" do
    test "calculates correct delay for ASPD 150" do
      # ASPD 150 should give (200 - 150) * 20 = 1000ms delay
      assert AttackSpeed.calculate_delay(150) == 1000
    end

    test "calculates correct delay for maximum ASPD 193" do
      # Maximum ASPD should give (200 - 193) * 20 = 140ms delay
      assert AttackSpeed.calculate_delay(193) == 140
    end

    test "calculates correct delay for minimum ASPD 0" do
      # Minimum ASPD should give (200 - 0) * 20 = 4000ms delay
      assert AttackSpeed.calculate_delay(0) == 4000
    end

    test "calculates correct delay for mid-range ASPD 100" do
      # ASPD 100 should give (200 - 100) * 20 = 2000ms delay
      assert AttackSpeed.calculate_delay(100) == 2000
    end

    test "190 ASPD is the classic 5 attacks per second" do
      assert AttackSpeed.calculate_delay(190) == 200
    end

    test "caps ASPD above 193 to maximum" do
      # Should treat ASPD > 193 as 193
      assert AttackSpeed.calculate_delay(200) == 140
      assert AttackSpeed.calculate_delay(999) == 140
    end

    test "caps ASPD below 0 to minimum" do
      # Should treat ASPD < 0 as 0
      assert AttackSpeed.calculate_delay(-10) == 4000
      assert AttackSpeed.calculate_delay(-999) == 4000
    end
  end

  describe "calculate_delay_from_stats/1" do
    test "extracts ASPD from stats and calculates delay" do
      stats = %{
        derived_stats: %{
          aspd: 160
        }
      }

      expected_delay = (200 - 160) * 20
      assert AttackSpeed.calculate_delay_from_stats(stats) == expected_delay
    end

    test "handles maximum ASPD in stats" do
      stats = %{
        derived_stats: %{
          aspd: 193
        }
      }

      assert AttackSpeed.calculate_delay_from_stats(stats) == 140
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
      last_attack = System.monotonic_time(:millisecond) - 200
      # Max ASPD delay
      attack_delay = 140

      assert AttackSpeed.can_attack?(last_attack, attack_delay) == true
    end

    test "handles very slow ASPD correctly" do
      # Slow ASPD with large delay
      last_attack = System.monotonic_time(:millisecond) - 1500
      # Min ASPD delay
      attack_delay = 4000

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
      # Should be around 880ms delay, a bit above one attack per second
      assert delay == 880
    end

    test "high-level character ASPD ~180 gives fast delay" do
      delay = AttackSpeed.calculate_delay(180)
      # Should be 400ms delay, 2.5 attacks per second
      assert delay == 400
    end

    test "slow weapon ASPD ~120 gives slow delay" do
      delay = AttackSpeed.calculate_delay(120)
      # Should be 1600ms delay
      assert delay == 1600
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
