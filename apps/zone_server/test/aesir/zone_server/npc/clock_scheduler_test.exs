defmodule Aesir.ZoneServer.Npc.ClockSchedulerTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Npc.ClockScheduler
  alias Aesir.ZoneServer.Npc.Registry

  # Sunday.
  @sunday_2359 ~N[2026-07-05 23:59:00]
  @sunday_2300 ~N[2026-07-05 23:00:00]
  @monday_2359 ~N[2026-07-06 23:59:00]

  defmodule FixtureNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 60, y: 60, sprite: 58, name: "Clock"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnMinute59", ctx) do
      send(:clock_scheduler_test_probe, {:fired, __MODULE__, ctx.npc_gid})
      ctx
    end
  end

  setup do
    on_exit(fn -> :persistent_term.erase(Registry) end)
    :ok
  end

  describe "matching_labels/2" do
    test "Sunday 23:59 matches OnSun2359, OnClock2359, OnMinute59 but not OnHour23" do
      labels = ["OnSun2359", "OnClock2359", "OnMinute59", "OnHour23"]

      assert ClockScheduler.matching_labels(labels, @sunday_2359) ==
               ["OnSun2359", "OnClock2359", "OnMinute59"]
    end

    test "Sunday 23:00 matches OnHour23, OnClock2300, OnMinute00" do
      labels = ["OnHour23", "OnClock2300", "OnMinute00", "OnSun2359"]

      assert ClockScheduler.matching_labels(labels, @sunday_2300) ==
               ["OnHour23", "OnClock2300", "OnMinute00"]
    end

    test "a non-matching clock label at the wrong time is excluded" do
      labels = ["OnClock0100"]

      assert ClockScheduler.matching_labels(labels, @sunday_2359) == []
    end

    test "a weekday label for the wrong day is excluded" do
      labels = ["OnMon2359"]

      assert ClockScheduler.matching_labels(labels, @sunday_2359) == []
      assert ClockScheduler.matching_labels(labels, @monday_2359) == ["OnMon2359"]
    end

    test "non-clock labels never match" do
      labels = ["OnStart", "OnTimer1000", "OnInit", "OnTouch"]

      assert ClockScheduler.matching_labels(labels, @sunday_2359) == []
    end

    test "non-zero-padded or garbage labels neither match nor crash" do
      labels = ["OnHour3", "OnClock999", "On", "OnX"]

      assert ClockScheduler.matching_labels(labels, @sunday_2359) == []
    end
  end

  describe "ms_until_next_minute/1" do
    test "at :00 exactly returns the full 60_000, not 0" do
      assert ClockScheduler.ms_until_next_minute(@sunday_2300) == 60_000
    end

    test "at :59.5 seconds returns the remaining 500ms" do
      now = %{@sunday_2359 | second: 59, microsecond: {500_000, 6}}

      assert ClockScheduler.ms_until_next_minute(now) == 500
    end

    test "at :59.999999 seconds truncates down to the remaining 1ms" do
      now = %{@sunday_2359 | second: 59, microsecond: {999_999, 6}}

      assert ClockScheduler.ms_until_next_minute(now) == 1
    end
  end

  describe "tick" do
    test "fires trigger_all for a registered NPC's matching OnMinute label" do
      Process.register(self(), :clock_scheduler_test_probe)
      Registry.reload([FixtureNpc])

      pid = start_supervised!({ClockScheduler, now_fun: fn -> @sunday_2359 end})

      send(pid, :tick)

      assert_receive {:fired, FixtureNpc, _gid}
    end

    test "with no clock labels registered, a tick is a no-op and re-arms" do
      Process.register(self(), :clock_scheduler_test_probe)
      Registry.reload([])

      pid = start_supervised!({ClockScheduler, now_fun: fn -> @sunday_2359 end})

      send(pid, :tick)

      refute_receive {:fired, _module, _gid}
      assert Process.alive?(pid)
    end
  end
end
