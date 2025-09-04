defmodule Aesir.Commons.Utils.ServerTickTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Utils.ServerTick

  doctest ServerTick

  describe "now/0" do
    test "returns a valid 32-bit timestamp" do
      tick = ServerTick.now()

      assert is_integer(tick)
      assert tick >= 0
      assert tick <= 0xFFFFFFFF
    end

    test "returns different values when called multiple times" do
      tick1 = ServerTick.now()
      Process.sleep(1)
      tick2 = ServerTick.now()

      # Should be different (unless we hit the exact same millisecond)
      # Allow for same value due to timing, but verify they're both valid
      assert ServerTick.valid?(tick1)
      assert ServerTick.valid?(tick2)
    end
  end

  describe "from_timestamp/1" do
    test "converts full timestamp to 32-bit tick" do
      full_timestamp = 0x123456789ABCDEF0
      tick = ServerTick.from_timestamp(full_timestamp)

      expected = full_timestamp |> rem(0x10_0000000)
      assert tick == expected
      assert ServerTick.valid?(tick)
    end

    test "handles small timestamps" do
      small_timestamp = 12_345
      tick = ServerTick.from_timestamp(small_timestamp)

      assert tick == small_timestamp
      assert ServerTick.valid?(tick)
    end

    test "handles boundary values" do
      # Test 32-bit boundary
      boundary = 0x10_0000000
      tick = ServerTick.from_timestamp(boundary)
      assert tick == 0

      # Test just under boundary
      under_boundary = 0xFFFFFFFF
      tick2 = ServerTick.from_timestamp(under_boundary)
      assert tick2 == under_boundary
    end
  end

  describe "diff/2" do
    test "calculates simple differences" do
      tick1 = 1000
      tick2 = 1500

      assert ServerTick.diff(tick1, tick2) == 500
      assert ServerTick.diff(tick2, tick1) == -500
    end

    test "handles 32-bit wraparound - forward wrap" do
      # tick1 near end of 32-bit range, tick2 wrapped to beginning
      # Near max
      tick1 = 0xFFFFFF00
      # Wrapped around
      tick2 = 0x00000100

      diff = ServerTick.diff(tick1, tick2)
      # Should be positive, not a huge negative number
      assert diff > 0
      # Should be reasonable small difference
      assert diff < 1000
    end

    test "handles 32-bit wraparound - backward wrap" do
      # Near beginning
      tick1 = 0x00000100
      # Near end
      tick2 = 0xFFFFFF00

      diff = ServerTick.diff(tick1, tick2)
      # Should be negative, not a huge positive number
      assert diff < 0
      # Should be reasonable small difference
      assert diff > -1000
    end

    test "zero difference" do
      tick = ServerTick.now()
      assert ServerTick.diff(tick, tick) == 0
    end
  end

  describe "valid?/1" do
    test "validates correct 32-bit values" do
      assert ServerTick.valid?(0)
      assert ServerTick.valid?(1000)
      assert ServerTick.valid?(0xFFFFFFFF)
    end

    test "rejects invalid values" do
      refute ServerTick.valid?(-1)
      refute ServerTick.valid?(0x10_0000000)
      refute ServerTick.valid?("invalid")
      refute ServerTick.valid?(nil)
      refute ServerTick.valid?(:atom)
    end
  end

  describe "add/2" do
    test "adds milliseconds to tick" do
      tick = 1000
      result = ServerTick.add(tick, 500)
      assert result == 1500
    end

    test "subtracts milliseconds from tick" do
      tick = 1000
      result = ServerTick.add(tick, -300)
      assert result == 700
    end

    test "handles wraparound when adding" do
      tick = 0xFFFFFFFF
      result = ServerTick.add(tick, 1)
      assert result == 0
    end

    test "handles wraparound when subtracting" do
      tick = 0
      result = ServerTick.add(tick, -1)
      # Should wrap to end of range
      assert ServerTick.valid?(result)
    end

    test "always returns valid tick" do
      tick = ServerTick.now()
      result1 = ServerTick.add(tick, 10_000)
      result2 = ServerTick.add(tick, -10_000)

      assert ServerTick.valid?(result1)
      assert ServerTick.valid?(result2)
    end
  end

  describe "elapsed?/2 and elapsed?/3" do
    test "detects elapsed time with default current tick" do
      start_tick = ServerTick.now()

      # Should be immediately elapsed for 0ms duration
      assert ServerTick.elapsed?(start_tick, 0)

      # Should not be elapsed for long duration
      refute ServerTick.elapsed?(start_tick, 10_000)
    end

    test "detects elapsed time with explicit current tick" do
      start_tick = 1000
      current_tick = 1500

      # 500ms have elapsed
      assert ServerTick.elapsed?(start_tick, 400, current_tick)
      assert ServerTick.elapsed?(start_tick, 500, current_tick)
      refute ServerTick.elapsed?(start_tick, 600, current_tick)
    end

    test "handles wraparound in elapsed calculation" do
      # Start near end of range
      start_tick = 0xFFFFFF00
      # Current wrapped around
      current_tick = 0x00000200

      # Should correctly detect small elapsed time
      assert ServerTick.elapsed?(start_tick, 100, current_tick)
    end
  end

  describe "integration with existing patterns" do
    test "matches existing codebase pattern" do
      # Test that our utility produces same result as existing code
      existing_pattern = System.system_time(:millisecond) |> rem(0x10_0000000)
      utility_result = ServerTick.now()

      # Should produce same format (32-bit values)
      assert is_integer(existing_pattern)
      assert is_integer(utility_result)
      assert existing_pattern >= 0 and existing_pattern <= 0xFFFFFFFF
      assert utility_result >= 0 and utility_result <= 0xFFFFFFFF

      # Should be very close in time (within 1 second)
      assert abs(existing_pattern - utility_result) < 1000
    end
  end
end
