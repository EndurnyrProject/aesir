defmodule Aesir.ZoneServer.Mmo.StatusEntryTest do
  use ExUnit.Case, async: true
  alias Aesir.ZoneServer.Mmo.StatusEntry

  describe "new/11" do
    test "creates a new status entry with required fields" do
      type = :poison
      val1 = 10
      val2 = 20
      val3 = 30
      val4 = 40
      tick = 1000
      flag = 1

      entry = StatusEntry.new(type, val1, val2, val3, val4, tick, flag)

      assert entry.type == type
      assert entry.val1 == val1
      assert entry.val2 == val2
      assert entry.val3 == val3
      assert entry.val4 == val4
      assert entry.tick == tick
      assert entry.flag == flag
      assert entry.tick_count == 0
      assert is_integer(entry.next_tick_at)
      # Default no expiration
      assert entry.expires_at == nil
    end

    test "creates a status with expiration when duration is provided" do
      type = :poison
      tick = 1000
      duration = 5000
      now = System.monotonic_time(:millisecond)

      entry = StatusEntry.new(type, 10, 20, 30, 40, tick, 1, duration)

      assert entry.expires_at != nil
      # Allow small time difference due to test execution
      assert entry.expires_at >= now + duration - 10
      assert entry.expires_at <= now + duration + 10
    end

    test "sets default values correctly" do
      entry = StatusEntry.new(:poison, 10, 20, 30, 40, 1000, 1)

      assert entry.source_id == nil
      assert entry.state == %{}
      assert entry.phase == nil
      assert is_integer(entry.started_at)
    end

    test "handles zero tick value by defaulting to 1000ms" do
      entry = StatusEntry.new(:poison, 10, 20, 30, 40, 0, 1)
      now = System.monotonic_time(:millisecond)

      assert entry.tick == 0
      assert entry.next_tick_at >= now + 990
      assert entry.next_tick_at <= now + 1010
    end
  end

  describe "from_map/1" do
    test "converts a map to a StatusEntry struct" do
      map = %{
        type: :poison,
        val1: 10,
        val2: 20,
        val3: 30,
        val4: 40,
        tick: 1000,
        flag: 1,
        source_id: 123,
        state: %{counter: 5},
        phase: :active,
        started_at: 100_000,
        expires_at: 200_000,
        next_tick_at: 101_000,
        tick_count: 5
      }

      entry = StatusEntry.from_map(map)

      assert %StatusEntry{} = entry
      assert entry.type == :poison
      assert entry.val1 == 10
      assert entry.val2 == 20
      assert entry.val3 == 30
      assert entry.val4 == 40
      assert entry.tick == 1000
      assert entry.flag == 1
      assert entry.source_id == 123
      assert entry.state == %{counter: 5}
      assert entry.phase == :active
      assert entry.started_at == 100_000
      assert entry.expires_at == 200_000
      assert entry.next_tick_at == 101_000
      assert entry.tick_count == 5
    end
  end

  describe "schedule_next_tick/2" do
    test "updates next_tick_at based on current time and tick value" do
      entry = StatusEntry.new(:poison, 10, 20, 30, 40, 2000, 1)
      now = System.monotonic_time(:millisecond)

      updated = StatusEntry.schedule_next_tick(entry, now)

      assert updated.next_tick_at == now + 2000
    end

    test "uses default 1000ms if tick value is 0" do
      entry = StatusEntry.new(:poison, 10, 20, 30, 40, 0, 1)
      now = System.monotonic_time(:millisecond)

      updated = StatusEntry.schedule_next_tick(entry, now)

      assert updated.next_tick_at == now + 1000
    end
  end

  describe "increment_tick_count/1" do
    test "increments the tick counter" do
      entry = %StatusEntry{tick_count: 5}

      updated = StatusEntry.increment_tick_count(entry)

      assert updated.tick_count == 6
    end
  end

  describe "expired?/2" do
    test "returns true when status has expired" do
      now = System.monotonic_time(:millisecond)
      # Expired 1 second ago
      entry = %StatusEntry{expires_at: now - 1000}

      assert StatusEntry.expired?(entry, now) == true
    end

    test "returns false when status hasn't expired yet" do
      now = System.monotonic_time(:millisecond)
      entry = %StatusEntry{expires_at: now + 1000}

      assert StatusEntry.expired?(entry, now) == false
    end

    test "returns false for permanent statuses with nil expiration" do
      entry = %StatusEntry{expires_at: nil}
      now = System.monotonic_time(:millisecond)

      assert StatusEntry.expired?(entry, now) == false
    end
  end

  describe "tick_due?/2" do
    test "returns true when status is due for a tick" do
      now = System.monotonic_time(:millisecond)
      entry = %StatusEntry{next_tick_at: now - 100}

      assert StatusEntry.tick_due?(entry, now) == true
    end

    test "returns false when status is not yet due for a tick" do
      now = System.monotonic_time(:millisecond)
      entry = %StatusEntry{next_tick_at: now + 100}

      assert StatusEntry.tick_due?(entry, now) == false
    end
  end
end
