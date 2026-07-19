defmodule Aesir.ZoneServer.Map.BossReconciliationTest do
  @moduledoc """
  Boot reconciliation of durable boss respawn deadlines.

  Reconciliation must never spawn or arm anything at boot: mob spawning is
  lazy, so anything spawned before the map's first visit would be spawned a
  second time by `spawn_all_mobs`. These tests drive the real path --
  `BossRespawn.reconcile/0`, `Coordinator.init/1`, then the first tick with a
  player on the map -- and assert every case yields exactly one boss.
  """

  use Aesir.DataCase, async: false
  use Mimic

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.BossRespawn, as: Row
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.BossRespawn
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.SpatialIndex

  # Osiris and Poring: real entries in the imported mob catalog, so the boss
  # lookups run against real mob data instead of a stub.
  @osiris_id 1038
  @poring_id 1002

  @one_boss "boss_reconciliation_one"
  @two_bosses "boss_reconciliation_two"
  @no_boss "boss_reconciliation_none"

  setup_all do
    key = Spawns
    # Force the real index to load before patching it, and restore it after.
    _ = Spawns.all()
    index = :persistent_term.get(key)

    patched =
      Map.update!(index, :by_map, fn by_map ->
        by_map
        |> Map.put(@one_boss, [boss_spawn(1)])
        |> Map.put(@two_bosses, [boss_spawn(2)])
        |> Map.put(@no_boss, [poring_spawn()])
      end)

    :persistent_term.put(key, patched)
    on_exit(fn -> :persistent_term.put(key, index) end)

    :ok
  end

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Enum.each([@one_boss, @two_bosses, @no_boss], fn map_name ->
      :ets.insert(EtsTable.table_for(:map_cache), {map_name, MapData.new(map_name, 200, 200)})
    end)

    test_pid = self()

    stub(MobSupervisor, :start_link, fn _map ->
      {:ok, spawn(fn -> Process.sleep(:infinity) end)}
    end)

    stub(MobSupervisor, :spawn_mob, fn _map, %MobState{} = mob_state, _opts ->
      send(test_pid, {:spawned, mob_state})
      {:ok, spawn(fn -> :ok end)}
    end)

    stub(MobSupervisor, :wake_all_mobs, fn _map -> :ok end)

    on_exit(fn -> :persistent_term.erase(BossRespawn) end)

    :ok
  end

  describe "boot reconciliation" do
    test "an overdue deadline yields exactly one boss on the map's first spawn" do
      write_deadline(@one_boss, @osiris_id, -60)
      :ok = BossRespawn.reconcile()

      {:ok, booted} = Coordinator.init(map_name: @one_boss)

      # Neither reconciliation nor coordinator boot may spawn or arm anything:
      # the map's first spawn would otherwise produce a second copy.
      assert [] == spawned_mob_ids()
      refute_received {:respawn_mob, _spawn_config}

      {:noreply, state} = tick_with_player(booted)

      assert state.mobs_spawned
      assert [@osiris_id] == spawned_mob_ids()
      refute_received {:respawn_mob, _spawn_config}
    end

    test "a future deadline skips the first spawn and the boss appears when its timer fires" do
      write_deadline(@one_boss, @osiris_id, 1)
      :ok = BossRespawn.reconcile()

      {:noreply, state} = first_visit(@one_boss)

      assert state.mobs_spawned
      assert [] == spawned_mob_ids()

      # The durable row must survive the skip, so the re-armed timer's spawn is
      # the one that consumes it.
      assert [%Row{mob_id: @osiris_id}] = Repo.all(Row)

      assert_receive {:respawn_mob, spawn_config}, 2_000

      {:noreply, _state} = Coordinator.handle_info({:respawn_mob, spawn_config}, state)

      assert [@osiris_id] == spawned_mob_ids()
      assert [] == Repo.all(Row)
    end

    test "a map with no pending deadlines spawns exactly as before" do
      :ok = BossRespawn.reconcile()

      {:noreply, _state} = first_visit(@one_boss)

      assert [@osiris_id] == spawned_mob_ids()
      refute_received {:respawn_mob, _spawn_config}
    end

    test "two pending rows for the same mob id resolve to two bosses, not one" do
      write_deadline(@two_bosses, @osiris_id, -60)
      write_deadline(@two_bosses, @osiris_id, 1)
      :ok = BossRespawn.reconcile()

      {:noreply, state} = first_visit(@two_bosses)

      assert [@osiris_id] == spawned_mob_ids()

      assert_receive {:respawn_mob, spawn_config}, 2_000

      {:noreply, _state} = Coordinator.handle_info({:respawn_mob, spawn_config}, state)

      assert [@osiris_id] == spawned_mob_ids()
    end

    test "an orphan row is logged and deleted, and nothing extra is spawned" do
      write_deadline(@no_boss, @osiris_id, 3_600)

      log = capture_log(fn -> assert :ok = BossRespawn.reconcile() end)

      assert log =~ "Discarding orphan boss respawn row for #{@no_boss}/#{@osiris_id}"
      assert [] == Repo.all(Row)

      {:noreply, _state} = first_visit(@no_boss)

      assert [@poring_id] == spawned_mob_ids()
      refute_received {:respawn_mob, _spawn_config}
    end

    test "boot issues one deadline query in total, not one per map" do
      rows = [
        %Row{id: 1, map_name: @one_boss, mob_id: @osiris_id, respawn_at: DateTime.utc_now()},
        %Row{id: 2, map_name: @two_bosses, mob_id: @osiris_id, respawn_at: DateTime.utc_now()}
      ]

      expect(Aesir.Repo, :all, 1, fn _queryable -> rows end)

      assert :ok = BossRespawn.reconcile()

      assert map_size(BossRespawn.deadlines_for(@one_boss)) == 1
      assert map_size(BossRespawn.deadlines_for(@two_bosses)) == 1
    end

    test "an unreachable repo degrades to no reconciliation instead of crashing boot" do
      write_deadline(@one_boss, @osiris_id, 3600)

      stub(Aesir.Repo, :all, fn _queryable ->
        raise DBConnection.ConnectionError, "down"
      end)

      log = capture_log(fn -> assert :ok = BossRespawn.reconcile() end)

      assert log =~ "Boss respawn reconciliation unavailable"
      assert BossRespawn.deadlines_for(@one_boss) == %{}

      {:ok, booted} = Coordinator.init(map_name: @one_boss)
      {:noreply, _state} = tick_with_player(booted)

      assert [@osiris_id] == spawned_mob_ids()
    end
  end

  defp boss_spawn(amount) do
    %MobSpawn{
      mob: @osiris_id,
      amount: amount,
      respawn_time: 60_000,
      respawn_variance: 0,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }
  end

  defp poring_spawn do
    %MobSpawn{
      mob: @poring_id,
      amount: 1,
      respawn_time: 5_000,
      respawn_variance: 0,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }
  end

  defp write_deadline(map_name, mob_id, offset_seconds) do
    :ok =
      BossRespawn.write(
        map_name,
        mob_id,
        DateTime.add(DateTime.utc_now(), offset_seconds, :second)
      )
  end

  # Boots a coordinator for `map_name` the way the supervision tree does, then
  # runs the first tick with a player present -- the tick that triggers the
  # map's lazy initial spawn.
  defp first_visit(map_name) do
    {:ok, state} = Coordinator.init(map_name: map_name)
    tick_with_player(state)
  end

  defp tick_with_player(state) do
    SpatialIndex.add_player(2001, 100, 100, state.map_name)
    Coordinator.handle_info(:broadcast_tick, state)
  end

  defp spawned_mob_ids do
    Enum.reverse(collect_spawned([]))
  end

  defp collect_spawned(acc) do
    receive do
      {:spawned, %MobState{mob_id: mob_id}} -> collect_spawned([mob_id | acc])
    after
      0 -> acc
    end
  end
end
