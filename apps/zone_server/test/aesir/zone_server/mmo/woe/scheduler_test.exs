defmodule Aesir.ZoneServer.Mmo.Woe.SchedulerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Mmo.Woe.Scheduler
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Mmo.Woe.Treasure

  # Fixed dates: 2026-07-05 is a Sunday, so 07-07 is a Tuesday and 07-11 a Saturday.
  @tue_window [{2, {21, 0}, {23, 0}}]
  @tue_2059 ~N[2026-07-07 20:59:00]
  @tue_2100 ~N[2026-07-07 21:00:00]
  @tue_2259 ~N[2026-07-07 22:59:00]
  @tue_2300 ~N[2026-07-07 23:00:00]
  @wed_2100 ~N[2026-07-08 21:00:00]

  setup :set_mimic_from_context

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

  test "matures once per date from 00:01 and spawns treasure only at 00:01" do
    owner = self()
    stub(Config, :woe_schedule, fn -> [] end)
    stub(Server, :active?, fn -> false end)
    stub(Economy, :mature_all, fn -> send(owner, {:daily, :mature}) end)
    stub(Treasure, :spawn_all, fn -> send(owner, {:daily, :treasure}) end)

    {scheduler, clock} =
      start_with_clock(~N[2026-07-07 00:00:00], [Config, Server, Economy, Treasure])

    for {now, expected} <- [
          {~N[2026-07-07 00:00:00], []},
          {~N[2026-07-07 00:01:00], [:mature, :treasure]},
          {~N[2026-07-07 00:02:00], []},
          {~N[2026-07-08 09:30:00], [:mature]},
          {~N[2026-07-09 00:01:00], [:mature, :treasure]}
        ] do
      tick(scheduler, clock, now)

      for action <- expected, do: assert_received({:daily, ^action})
      refute_received {:daily, _}
    end
  end

  test "starts and stops only on siege transitions" do
    owner = self()
    stub(Config, :woe_schedule, fn -> @tue_window end)
    stub(Economy, :mature_all, fn -> :ok end)

    active = start_supervised!({Agent, fn -> false end}, id: :siege_active)
    stub(Server, :active?, fn -> Agent.get(active, & &1) end)

    stub(Server, :start, fn ->
      Agent.update(active, fn _ -> true end)
      send(owner, :started)
    end)

    stub(Server, :stop, fn ->
      Agent.update(active, fn _ -> false end)
      send(owner, :stopped)
    end)

    {scheduler, clock} = start_with_clock(@tue_2059, [Config, Server, Economy])

    tick(scheduler, clock, @tue_2059)
    refute_received :started

    tick(scheduler, clock, @tue_2100)
    assert_received :started

    tick(scheduler, clock, @tue_2259)
    refute_received :started

    tick(scheduler, clock, @tue_2300)
    assert_received :stopped

    tick(scheduler, clock, @wed_2100)
    refute_received :stopped
  end

  defp start_with_clock(now, modules) do
    owner = self()
    clock = start_supervised!({Agent, fn -> now end})

    scheduler =
      start_supervised!({Scheduler, name: __MODULE__, now_fun: fn -> Agent.get(clock, & &1) end})

    for module <- modules, do: Mimic.allow(module, owner, scheduler)
    {scheduler, clock}
  end

  defp tick(scheduler, clock, now) do
    Agent.update(clock, fn _ -> now end)
    send(scheduler, :tick)
    :sys.get_state(scheduler)
  end
end
