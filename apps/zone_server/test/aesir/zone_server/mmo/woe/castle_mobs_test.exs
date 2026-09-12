defmodule Aesir.ZoneServer.Mmo.Woe.CastleMobsTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleMobs
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor

  setup :set_mimic_private

  defp totals({:ok, %{roaming: roaming, room: room}}) do
    {Enum.sum_by(roaming, &elem(&1, 1)), Enum.sum_by(room, &elem(&1, 1))}
  end

  describe "set_for/1" do
    test "resolves each region's roaming/room set by map prefix" do
      assert totals(CastleMobs.set_for("aldeg_cas01")) == {67, 12}
      assert totals(CastleMobs.set_for("gefg_cas01")) == {74, 22}
      assert totals(CastleMobs.set_for("payg_cas01")) == {56, 13}
      assert totals(CastleMobs.set_for("prtg_cas01")) == {35, 9}
    end

    test "returns the exact mob id and amount lists for each region" do
      assert {:ok, %{roaming: aldeg_roaming, room: aldeg_room}} =
               CastleMobs.set_for("aldeg_cas01")

      assert aldeg_roaming == [
               {1117, 10},
               {1132, 4},
               {1219, 2},
               {1205, 1},
               {1216, 10},
               {1193, 18},
               {1269, 9},
               {1276, 7},
               {1208, 3},
               {1275, 1},
               {1268, 1},
               {1272, 1}
             ]

      assert aldeg_room == [{1272, 1}, {1270, 4}, {1268, 1}, {1219, 1}, {1276, 5}]

      assert {:ok, %{roaming: gefg_roaming, room: gefg_room}} = CastleMobs.set_for("gefg_cas01")

      assert gefg_roaming == [
               {1117, 10},
               {1263, 11},
               {1102, 10},
               {1130, 10},
               {1140, 20},
               {1163, 9},
               {1275, 1},
               {1219, 1},
               {1150, 1},
               {1159, 1}
             ]

      assert gefg_room == [{1203, 1}, {1087, 1}, {1213, 10}, {1189, 10}]

      assert {:ok, %{roaming: payg_roaming, room: payg_room}} = CastleMobs.set_for("payg_cas01")

      assert payg_roaming == [
               {1277, 9},
               {1208, 10},
               {1262, 5},
               {1102, 5},
               {1150, 1},
               {1115, 1},
               {1129, 11},
               {1276, 5},
               {1282, 4},
               {1253, 5}
             ]

      assert payg_room == [{1150, 1}, {1115, 1}, {1208, 6}, {1276, 5}]

      assert {:ok, %{roaming: prtg_roaming, room: prtg_room}} = CastleMobs.set_for("prtg_cas01")

      assert prtg_roaming == [
               {1163, 1},
               {1132, 10},
               {1219, 5},
               {1268, 5},
               {1251, 1},
               {1252, 1},
               {1276, 5},
               {1259, 2},
               {1283, 3},
               {1275, 1},
               {1200, 1}
             ]

      assert prtg_room == [{1268, 1}, {1251, 1}, {1252, 1}, {1219, 1}, {1276, 5}]
    end

    test "errors for a map with no matching region" do
      assert CastleMobs.set_for("prontera") == :error
    end

    test "resolves a set for every castle in the shipped catalog" do
      for castle <- CastleDb.all() do
        assert {:ok, _set} = CastleMobs.set_for(castle.map)
      end
    end
  end

  describe "seed/1" do
    setup do
      [castle | _] = Enum.filter(CastleDb.all(), &String.starts_with?(&1.map, "aldeg_"))
      %{castle: castle}
    end

    test "wipes before summoning, then summons one instance per mob at the documented cells",
         %{castle: castle} do
      test_pid = self()
      {ex, ey} = castle.emperium

      expect(MobSupervisor, :kill_all, fn map ->
        assert map == castle.map
        send(test_pid, :wiped)
        :ok
      end)

      expect(Coordinator, :summon_mob, 79, fn map, mob_id, x, y, opts ->
        assert map == castle.map
        assert opts == []
        assert is_integer(mob_id)
        assert {x, y} == {0, 0} or {x, y} == {ex, ey}
        send(test_pid, :summoned)
        {:ok, System.unique_integer([:positive])}
      end)

      assert CastleMobs.seed(castle) == :ok
      assert_received :wiped
      for _ <- 1..79, do: assert_received(:summoned)
    end

    test "a failed summon does not stop the remaining summons", %{castle: castle} do
      stub(MobSupervisor, :kill_all, fn _map -> :ok end)

      test_pid = self()

      stub(Coordinator, :summon_mob, fn
        _map, 1117, _x, _y, _opts ->
          send(test_pid, :summoned)
          {:error, :no_walkable_cell}

        _map, _mob_id, _x, _y, _opts ->
          send(test_pid, :summoned)
          {:ok, System.unique_integer([:positive])}
      end)

      assert CastleMobs.seed(castle) == :ok

      for _ <- 1..79, do: assert_received(:summoned)
    end

    test "does nothing for a map with no region set" do
      castle = %Castle{
        id: 999,
        map: "prontera",
        name: "Not A Castle",
        client_id: 0,
        emperium: {5, 5},
        respawn: {5, 5},
        treasure: %{box_id: 1, cells: []},
        guardians: []
      }

      reject(&MobSupervisor.kill_all/1)
      reject(&Coordinator.summon_mob/5)

      assert CastleMobs.seed(castle) == :ok
    end
  end

  describe "wipe/1" do
    test "kills all mobs on the castle map" do
      castle = %Castle{
        id: 1,
        map: "aldeg_cas01",
        name: "Neuschwanstein",
        client_id: 0,
        emperium: {5, 5},
        respawn: {5, 5},
        treasure: %{box_id: 1, cells: []},
        guardians: []
      }

      expect(MobSupervisor, :kill_all, fn "aldeg_cas01" -> :ok end)

      assert CastleMobs.wipe(castle) == :ok
    end
  end
end
