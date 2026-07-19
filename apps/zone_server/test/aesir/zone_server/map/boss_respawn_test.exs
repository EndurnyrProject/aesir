defmodule Aesir.ZoneServer.Map.BossRespawnTest do
  use Aesir.DataCase, async: false
  use Mimic

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.BossRespawn, as: Row
  alias Aesir.ZoneServer.Map.BossRespawn
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Osiris: a real MVP-tier boss in the imported mob catalog, so the delete
  # side (which resolves boss-ness through `MobManagement.get_mob_by_id/1`)
  # exercises the real lookup instead of a stub.
  @osiris_id 1038
  @poring_id 1002

  setup :setup_ets_tables
  setup :verify_on_exit!

  describe "write/3" do
    test "persists a pending deadline row" do
      respawn_at = DateTime.utc_now() |> DateTime.add(10_000, :millisecond)

      assert :ok = BossRespawn.write("gld_dun03", 1039, respawn_at)

      assert [%Row{map_name: "gld_dun03", mob_id: 1039}] = Repo.all(Row)
    end

    test "a repo failure is logged and swallowed instead of raising" do
      stub(Aesir.Repo, :insert, fn _changeset -> raise DBConnection.ConnectionError, "down" end)

      respawn_at = DateTime.utc_now() |> DateTime.add(10_000, :millisecond)

      log =
        capture_log(fn ->
          assert :ok = BossRespawn.write("gld_dun03", 1039, respawn_at)
        end)

      assert log =~ "Boss respawn persistence unavailable"
    end
  end

  describe "delete/2" do
    test "removes the pending row for the given map and mob" do
      respawn_at = DateTime.utc_now() |> DateTime.add(10_000, :millisecond)
      :ok = BossRespawn.write("gld_dun03", 1039, respawn_at)

      assert :ok = BossRespawn.delete("gld_dun03", 1039)

      assert Repo.all(Row) == []
    end

    test "is a no-op when no row matches" do
      assert :ok = BossRespawn.delete("gld_dun03", 1039)
    end

    test "leaves other maps and mobs untouched" do
      respawn_at = DateTime.utc_now() |> DateTime.add(10_000, :millisecond)
      :ok = BossRespawn.write("gld_dun03", 1039, respawn_at)
      :ok = BossRespawn.write("prontera", 1002, respawn_at)

      :ok = BossRespawn.delete("gld_dun03", 1039)

      assert [%Row{map_name: "prontera", mob_id: 1002}] = Repo.all(Row)
    end
  end

  describe "list_pending/0" do
    test "returns every pending row" do
      respawn_at = DateTime.utc_now() |> DateTime.add(10_000, :millisecond)
      :ok = BossRespawn.write("gld_dun03", 1039, respawn_at)
      :ok = BossRespawn.write("prontera", 1002, respawn_at)

      rows = BossRespawn.list_pending()

      assert length(rows) == 2
      assert Enum.all?(rows, &match?(%Row{}, &1))
    end
  end

  describe "Coordinator wiring" do
    test "a boss death writes a row, and its respawn deletes it" do
      instance_id = System.unique_integer([:positive])

      spawn_config = %MobSpawn{
        mob: @osiris_id,
        amount: 1,
        respawn_time: 10_000,
        respawn_variance: 0,
        spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
      }

      mob_state =
        MobState.new(
          instance_id,
          mob_definition(@osiris_id, boss?: true),
          spawn_config,
          "prontera",
          100,
          100
        )

      UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, self())

      died_state = %Coordinator{map_name: "prontera", respawn_timers: %{}, next_mob_id: 1}

      before_death = DateTime.utc_now()

      {:noreply, respawn_state} =
        Coordinator.handle_cast({:mob_died, instance_id, nil}, died_state)

      osiris_id = @osiris_id
      assert [%Row{map_name: "prontera", mob_id: ^osiris_id} = row] = Repo.all(Row)
      assert DateTime.diff(row.respawn_at, before_death, :millisecond) in 9_000..11_000

      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)

      {:noreply, _final_state} =
        Coordinator.handle_info({:respawn_mob, spawn_config}, respawn_state)

      assert Repo.all(Row) == []
    end

    test "a non-boss mob death writes no row" do
      instance_id = System.unique_integer([:positive])

      spawn_config = %MobSpawn{
        mob: @poring_id,
        amount: 1,
        respawn_time: 5_000,
        respawn_variance: 0,
        spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
      }

      mob_state =
        MobState.new(
          instance_id,
          mob_definition(@poring_id, boss?: false),
          spawn_config,
          "prontera",
          100,
          100
        )

      UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, self())

      state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      {:noreply, _new_state} = Coordinator.handle_cast({:mob_died, instance_id, nil}, state)

      assert Repo.all(Row) == []
    end

    test "a repo failure during a boss death is logged and does not crash the coordinator or block the timer" do
      stub(Aesir.Repo, :insert, fn _changeset -> raise DBConnection.ConnectionError, "down" end)

      instance_id = System.unique_integer([:positive])

      spawn_config = %MobSpawn{
        mob: @osiris_id,
        amount: 1,
        respawn_time: 10_000,
        respawn_variance: 0,
        spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
      }

      mob_state =
        MobState.new(
          instance_id,
          mob_definition(@osiris_id, boss?: true),
          spawn_config,
          "prontera",
          100,
          100
        )

      UnitRegistry.register_unit(:mob, instance_id, MobState, mob_state, self())

      state = %Coordinator{map_name: "prontera", respawn_timers: %{}}

      log =
        capture_log(fn ->
          assert {:noreply, new_state} =
                   Coordinator.handle_cast({:mob_died, instance_id, nil}, state)

          assert {timer_ref, ^spawn_config} = Map.fetch!(new_state.respawn_timers, instance_id)
          assert Process.read_timer(timer_ref)
        end)

      assert log =~ "Boss respawn persistence unavailable"
      assert Repo.all(Row) == []
    end

    test "a non-boss respawn issues no delete query" do
      test = self()

      stub(Aesir.Repo, :delete_all, fn query ->
        send(test, {:delete_all, query})
        {0, nil}
      end)

      stub(MobSupervisor, :spawn_mob, fn _map_name, _mob_state, _awake -> {:ok, self()} end)

      spawn_config = %MobSpawn{
        mob: @poring_id,
        amount: 1,
        respawn_time: 5_000,
        respawn_variance: 0,
        spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
      }

      state = %Coordinator{
        map_name: "prontera",
        respawn_timers: %{},
        map_data: %{width: 512, height: 512},
        mobs_awake: true,
        next_mob_id: 1
      }

      Coordinator.handle_info({:respawn_mob, spawn_config}, state)

      refute_received {:delete_all, _query}
    end
  end

  defp mob_definition(mob_id, boss?: boss?) do
    %MobDefinition{
      id: mob_id,
      aegis_name: "test_mob_#{mob_id}",
      name: "Test Mob #{mob_id}",
      level: 1,
      hp: 100,
      sp: 0,
      stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
      atk: 10,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      modes: if(boss?, do: [:boss], else: [])
    }
  end
end
