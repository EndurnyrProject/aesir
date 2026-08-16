defmodule Aesir.ZoneServer.Mmo.Woe.SchedulerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Woe.Scheduler
  alias Aesir.ZoneServer.Mmo.Woe.Server

  # Fixed dates: 2026-07-05 is a Sunday, so 07-07 is a Tuesday and 07-11 a Saturday.
  @tue_window [{2, {21, 0}, {23, 0}}]
  @tue_2059 ~N[2026-07-07 20:59:00]
  @tue_2100 ~N[2026-07-07 21:00:00]
  @tue_2259 ~N[2026-07-07 22:59:00]
  @tue_2300 ~N[2026-07-07 23:00:00]
  @wed_2100 ~N[2026-07-08 21:00:00]

  describe "Config.woe_schedule/0" do
    test "defaults to Tue/Thu 21:00-23:00 and Sat 16:00-18:00" do
      assert Config.woe_schedule() ==
               [{2, {21, 0}, {23, 0}}, {4, {21, 0}, {23, 0}}, {6, {16, 0}, {18, 0}}]
    end
  end

  describe "desired_state/2" do
    test "is :active only inside the window, across day and edge boundaries" do
      assert Scheduler.desired_state(@tue_window, @tue_2059) == :inactive
      assert Scheduler.desired_state(@tue_window, @tue_2100) == :active
      assert Scheduler.desired_state(@tue_window, @tue_2259) == :active
      assert Scheduler.desired_state(@tue_window, @tue_2300) == :inactive
      assert Scheduler.desired_state(@tue_window, @wed_2100) == :inactive
    end

    test "a window wrapping past midnight is active on both sides" do
      windows = [{2, {23, 0}, {1, 0}}]

      assert Scheduler.desired_state(windows, ~N[2026-07-07 23:30:00]) == :active
      assert Scheduler.desired_state(windows, ~N[2026-07-08 00:30:00]) == :active
      assert Scheduler.desired_state(windows, ~N[2026-07-08 01:30:00]) == :inactive
      assert Scheduler.desired_state(windows, ~N[2026-07-07 22:30:00]) == :inactive

      # A Sunday window wraps across the week boundary into Monday.
      week_windows = [{7, {23, 0}, {1, 0}}]
      assert Scheduler.desired_state(week_windows, ~N[2026-07-12 23:30:00]) == :active
      assert Scheduler.desired_state(week_windows, ~N[2026-07-13 00:30:00]) == :active
      assert Scheduler.desired_state(week_windows, ~N[2026-07-13 01:30:00]) == :inactive
    end

    test "an empty schedule is always :inactive" do
      assert Scheduler.desired_state([], @tue_2100) == :inactive
    end
  end

  describe "tick" do
    test "calls start/0 and stop/0 only on transitions, never while steady" do
      test_pid = self()

      Application.put_env(:zone_server, :woe_schedule, @tue_window)
      on_exit(fn -> Application.delete_env(:zone_server, :woe_schedule) end)

      {:ok, clock} = Agent.start_link(fn -> @tue_2059 end)
      {:ok, active} = Agent.start_link(fn -> false end)
      now_fun = fn -> Agent.get(clock, & &1) end

      Mimic.copy(Server)
      stub(Server, :active?, fn -> Agent.get(active, & &1) end)

      stub(Server, :start, fn ->
        Agent.update(active, fn _ -> true end)
        send(test_pid, :started)
      end)

      stub(Server, :stop, fn ->
        Agent.update(active, fn _ -> false end)
        send(test_pid, :stopped)
      end)

      pid = start_supervised!({Scheduler, now_fun: now_fun})
      Mimic.allow(Server, self(), pid)

      # Steady :inactive -> no call.
      send(pid, :tick)
      refute_receive :started, 100

      # inactive -> active: exactly one start.
      Agent.update(clock, fn _ -> @tue_2100 end)
      send(pid, :tick)
      assert_receive :started, 100

      # Steady :active -> no further call.
      send(pid, :tick)
      refute_receive :started, 100

      # active -> inactive: exactly one stop.
      Agent.update(clock, fn _ -> @tue_2300 end)
      send(pid, :tick)
      assert_receive :stopped, 100

      # Steady :inactive again -> no call.
      send(pid, :tick)
      refute_receive :stopped, 100
    end
  end
end
