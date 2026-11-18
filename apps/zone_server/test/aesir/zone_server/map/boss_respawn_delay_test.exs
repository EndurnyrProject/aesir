defmodule Aesir.ZoneServer.Map.BossRespawnDelayTest do
  @moduledoc """
  `Coordinator`'s `{:mob_died, ...}` handler rolls the spawn variance only for a
  `boss_monster` spawn line, scales a status-immune mob's delay by the boss
  percentage, and floors every delay at 1000 ms.

  `handle_cast/2` is exercised directly (no live `Coordinator` process), as
  `CoordinatorTest` already does for `handle_call/3`: `Process.send_after/3`
  then sends to the calling test process, so `Process.read_timer/1` reads the
  scheduled interval back synchronously without waiting on a real timer.

  `read_timer/1` reports the time *remaining*, which has already ticked down by
  a millisecond or two by the time it is read. Assertions therefore allow a
  small tolerance rather than exact equality — asserting `== 10_000` fails on
  roughly a third of runs.
  """

  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Factory

  alias Aesir.TestMob
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @tolerance_ms 50

  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "a boss_monster line with zero variance respawns after exactly its base delay" do
    assert Config.boss_respawn_delay_percentage() == 100

    remaining =
      mob_died_delay(boss_line?: true, immune?: true, respawn_time: 10_000, respawn_variance: 0)

    assert_scheduled(remaining, 10_000)
  end

  test "a boss_monster line rolls its variance in [base, base + variance - 1]" do
    respawn_time = 10_000
    variance = 2_000

    samples =
      for instance_id <- 1..20 do
        mob_died_delay(
          instance_id: instance_id,
          boss_line?: true,
          immune?: false,
          respawn_time: respawn_time,
          respawn_variance: variance
        )
      end

    assert Enum.all?(samples, &(&1 >= respawn_time - @tolerance_ms))
    assert Enum.all?(samples, &(&1 <= respawn_time + variance - 1))
    assert Enum.uniq(samples) |> length() > 1
  end

  test "a plain monster line ignores its variance, even for a boss-class mob" do
    remaining =
      mob_died_delay(
        boss_line?: false,
        immune?: true,
        respawn_time: 5_000,
        respawn_variance: 3_000
      )

    assert_scheduled(remaining, 5_000)
  end

  test "a status-immune mob's delay is divided by 100 before the boss percentage" do
    stub(Config, :boss_respawn_delay_percentage, fn -> 50 end)

    remaining =
      mob_died_delay(boss_line?: false, immune?: true, respawn_time: 10_099, respawn_variance: 0)

    assert_scheduled(remaining, 5_000)
  end

  test "a mob that is not status-immune ignores the boss percentage, even on a boss_monster line" do
    stub(Config, :boss_respawn_delay_percentage, fn -> 50 end)

    remaining =
      mob_died_delay(boss_line?: true, immune?: false, respawn_time: 5_000, respawn_variance: 0)

    assert_scheduled(remaining, 5_000)
  end

  test "every mob's interval is floored at 1000 ms" do
    remaining =
      mob_died_delay(boss_line?: false, immune?: false, respawn_time: 100, respawn_variance: 0)

    assert_scheduled(remaining, 1_000)

    stub(Config, :boss_respawn_delay_percentage, fn -> 10 end)

    remaining =
      mob_died_delay(boss_line?: true, immune?: true, respawn_time: 100, respawn_variance: 0)

    assert_scheduled(remaining, 1_000)
  end

  defp assert_scheduled(remaining, expected) do
    assert remaining <= expected
    assert remaining > expected - @tolerance_ms
  end

  defp mob_died_delay(opts) do
    instance_id = Keyword.get(opts, :instance_id, System.unique_integer([:positive]))
    boss_line? = Keyword.fetch!(opts, :boss_line?)
    immune? = Keyword.fetch!(opts, :immune?)
    respawn_time = Keyword.fetch!(opts, :respawn_time)
    respawn_variance = Keyword.fetch!(opts, :respawn_variance)

    spawn_ref =
      build(:mob_spawn,
        respawn_time: respawn_time,
        respawn_variance: respawn_variance,
        boss: boss_line?
      )

    modes = if immune?, do: [:status_immune], else: []

    mob_state =
      MobState.new(instance_id, TestMob.definition(modes: modes), spawn_ref, "prontera", 150, 150)

    UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, self())

    state = build(:coordinator_state)

    {:noreply, new_state} = Coordinator.handle_cast({:mob_died, instance_id, nil}, state)

    {timer_ref, ^spawn_ref} = Map.fetch!(new_state.respawn_timers, instance_id)
    Process.read_timer(timer_ref)
  end
end
