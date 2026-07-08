defmodule Aesir.ZoneServer.Map.CoordinatorTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

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

    test "replies with the error when the mob id is unknown" do
      state = %Coordinator{map_name: "prontera", next_mob_id: 1}

      assert {:reply, {:error, :mob_not_found}, ^state} =
               Coordinator.handle_call({:summon_mob, 9_999_999, 10, 10, []}, {self(), nil}, state)
    end
  end
end
