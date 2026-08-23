defmodule Aesir.ZoneServer.Map.CoordinatorTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.WorldId

  @poring_id 1002

  describe "mob_died/2 routing" do
    test "routes a .gat-suffixed map name to the clean-named coordinator" do
      # Coordinators register under the clean map name (no .gat). mob_died still
      # tolerates a .gat-suffixed name from any caller, stripping it so the cast
      # is not routed to an unregistered .gat name.
      {:ok, _} = Registry.register(Aesir.ZoneServer.MapRegistry, "coordinator_test_map", nil)

      Coordinator.mob_died("coordinator_test_map.gat", 4242)

      assert_receive {:"$gen_cast", {:mob_died, 4242, nil}}
    end
  end

  describe "summon_mob handling" do
    setup :setup_ets_tables

    test "registers the summoned mob in UnitRegistry so it is attackable" do
      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      {:reply, {:ok, instance_id}, _new_state} =
        Coordinator.handle_call({:summon_mob, @poring_id, 150, 100, []}, {self(), nil}, state)

      assert {:ok, {MobState, %MobState{} = mob, _pid}} =
               UnitRegistry.get_unit(:mob, instance_id)

      assert mob.mob_id == @poring_id
      assert {mob.x, mob.y} == {150, 100}
      assert mob.map_name == "prontera"
    end

    test "non-positive coordinates pick a random walkable cell (rAthena 0,0 semantics)" do
      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)

      map_data = MapData.new("prontera", 40, 40)
      :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map_data})

      state = %Coordinator{map_name: "prontera", map_data: map_data, next_mob_id: 1}

      {:reply, {:ok, instance_id}, _new_state} =
        Coordinator.handle_call({:summon_mob, @poring_id, 0, 0, []}, {self(), nil}, state)

      assert {:ok, {MobState, %MobState{} = mob, _pid}} =
               UnitRegistry.get_unit(:mob, instance_id)

      assert mob.x in 0..39
      assert mob.y in 0..39
    end

    test "threads summon ownership, reward, HP, and lifetime options" do
      test_pid = self()

      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{} = mob, opts ->
        send(test_pid, {:spawned, mob, opts})
        {:ok, self()}
      end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      opts = [
        owner_player_id: 42,
        hp_override: 2_345,
        lifetime_ms: 50,
        no_exp: true,
        no_drops: true
      ]

      {:reply, {:ok, instance_id}, _new_state} =
        Coordinator.handle_call({:summon_mob, @poring_id, 150, 100, opts}, {self(), nil}, state)

      assert_received {:spawned,
                       %MobState{
                         owner_player_id: 42,
                         hp: 2_345,
                         max_hp: 2_345,
                         no_exp: true,
                         no_drops: true
                       }, session_opts}

      assert session_opts[:lifetime_ms] == 50

      assert {:ok, {MobState, %MobState{owner_player_id: 42, no_exp: true, no_drops: true}, _pid}} =
               UnitRegistry.get_unit(:mob, instance_id)
    end

    test "threads a :master_id opt onto the spawned mob (slave link)" do
      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      {:reply, {:ok, instance_id}, _new_state} =
        Coordinator.handle_call(
          {:summon_mob, @poring_id, 150, 100, [master_id: 777]},
          {self(), nil},
          state
        )

      assert {:ok, {MobState, %MobState{master_id: 777}, _pid}} =
               UnitRegistry.get_unit(:mob, instance_id)
    end

    test "a summon without :master_id spawns masterless" do
      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      {:reply, {:ok, instance_id}, _new_state} =
        Coordinator.handle_call({:summon_mob, @poring_id, 150, 100, []}, {self(), nil}, state)

      assert {:ok,
              {MobState,
               %MobState{
                 master_id: nil,
                 owner_player_id: nil,
                 no_exp: false,
                 no_drops: false
               }, _pid}} = UnitRegistry.get_unit(:mob, instance_id)
    end

    test "a killed summon is not scheduled for respawn" do
      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      {:reply, {:ok, instance_id}, new_state} =
        Coordinator.handle_call({:summon_mob, @poring_id, 150, 100, []}, {self(), nil}, state)

      assert {:noreply, after_death} =
               Coordinator.handle_cast({:mob_died, instance_id, nil}, new_state)

      assert after_death.respawn_timers == new_state.respawn_timers
      refute_receive {:respawn_mob, _}, 50
    end

    test "rejects a fixed summon cell occupied by an active movement blocker" do
      map_data = MapData.new("prontera", 300, 300)
      :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map_data})
      :ok = Cell.put("prontera", 150, 100, :test_blocker, 1, blocks_movement: true)
      reject(&MobSupervisor.spawn_mob/3)

      state = %Coordinator{map_name: "prontera", map_data: map_data, next_mob_id: 1}

      assert {:reply, {:error, :no_walkable_cell}, ^state} =
               Coordinator.handle_call(
                 {:summon_mob, @poring_id, 150, 100, []},
                 {self(), nil},
                 state
               )
    end

    test "releases the claimed world ID when the mob session fails to start" do
      test_pid = self()

      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{instance_id: instance_id}, _opts ->
        send(test_pid, {:claimed_instance_id, instance_id})
        {:error, :start_failed}
      end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      assert {:reply, {:error, :start_failed}, ^state} =
               Coordinator.handle_call(
                 {:summon_mob, @poring_id, 150, 100, []},
                 {self(), nil},
                 state
               )

      assert_received {:claimed_instance_id, instance_id}
      refute UnitRegistry.unit_id_exists?(instance_id)
    end

    test "replies with the error when the mob id is unknown" do
      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      assert {:reply, {:error, :mob_not_found}, ^state} =
               Coordinator.handle_call({:summon_mob, 9_999_999, 10, 10, []}, {self(), nil}, state)
    end

    test "summon_mob/5 returns :map_not_found when no coordinator runs for the map" do
      assert {:error, :map_not_found} =
               Coordinator.summon_mob("no_such_map_registered", @poring_id, 10, 10)
    end

    test "handle_call({:summon_mob_area, ...}) spawns at a random walkable cell inside the rectangle" do
      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)

      map_data = MapData.new("prontera", 40, 40)
      :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map_data})

      state = %Coordinator{map_name: "prontera", map_data: map_data, next_mob_id: 1}

      {:reply, {:ok, instance_id}, _new_state} =
        Coordinator.handle_call(
          {:summon_mob_area, @poring_id, {10, 10, 15, 20}, []},
          {self(), nil},
          state
        )

      assert {:ok, {MobState, %MobState{} = mob, _pid}} =
               UnitRegistry.get_unit(:mob, instance_id)

      assert mob.x in 10..15
      assert mob.y in 10..20
    end

    test "summon_mob_area/4 returns :map_not_found when no coordinator runs for the map" do
      assert {:error, :map_not_found} =
               Coordinator.summon_mob_area("no_such_map_registered", @poring_id, {10, 10, 20, 20})
    end
  end

  describe "mob instance id allocation" do
    setup :setup_ets_tables

    test "delegates allocation with the existing mob ID range" do
      Mimic.copy(WorldId)
      stub(MobSupervisor, :spawn_mob, fn _map, %MobState{}, _opts -> {:ok, self()} end)
      test_pid = self()

      stub(WorldId, :allocate, fn range, unit_type ->
        send(test_pid, {:allocated, range, unit_type})
        {:ok, 123_456}
      end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      assert {:reply, {:ok, 123_456}, _new_state} =
               Coordinator.handle_call(
                 {:summon_mob, @poring_id, 150, 100, []},
                 {self(), nil},
                 state
               )

      assert_received {:allocated, 2..1_999_999, :mob}
    end

    test "fails fast when the world ID range is exhausted" do
      Mimic.copy(WorldId)
      stub(WorldId, :allocate, fn 2..1_999_999, :mob -> {:error, :exhausted} end)

      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      assert_raise RuntimeError, "world ID range exhausted", fn ->
        Coordinator.handle_call({:summon_mob, @poring_id, 150, 100, []}, {self(), nil}, state)
      end
    end
  end
end
