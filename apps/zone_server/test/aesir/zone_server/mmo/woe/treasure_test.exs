defmodule Aesir.ZoneServer.Mmo.Woe.TreasureTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Treasure

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok
  end

  defp fixture_castle(id, map, box_id) do
    %Castle{
      id: id,
      map: map,
      name: "Test Castle",
      client_id: 1,
      emperium: {50, 50},
      respawn: {50, 55},
      treasure: %{box_id: box_id, cells: for(i <- 0..23, do: {100 + i, 200 + i})}
    }
  end

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{guild_id: guild_id, economy: 0, defense: 0, invested_economy: 0, invested_defense: 0},
      overrides
    )
  end

  describe "plan/3" do
    test "plans 4 boxes at economy 0" do
      assert length(Treasure.plan(fixture_castle(1, "test_map", 7_000), 0, [])) == 4
    end

    test "plans 24 boxes at economy 100" do
      assert length(Treasure.plan(fixture_castle(1, "test_map", 7_000), 100, [])) == 24
    end

    test "plans 9 boxes at economy 27" do
      assert length(Treasure.plan(fixture_castle(1, "test_map", 7_000), 27, [])) == 9
    end

    test "alternates box ids across the castle's cells" do
      castle = fixture_castle(1, "test_map", 7_000)

      assert Treasure.plan(castle, 0, []) == [
               {0, 7_000, 100, 200},
               {1, 7_001, 101, 201},
               {2, 7_000, 102, 202},
               {3, 7_001, 103, 203}
             ]
    end

    test "omits slots already live" do
      castle = fixture_castle(1, "test_map", 7_000)

      assert Enum.map(Treasure.plan(castle, 0, [0, 2]), fn {slot, _, _, _} -> slot end) == [1, 3]
    end
  end

  describe "spawn_daily/1" do
    test "logs and returns :ok without inserting when no coordinator runs the map" do
      castle = fixture_castle(9_001, "no_such_map", 7_000)

      assert :ok = Treasure.spawn_daily(castle)
      assert Treasure.live_slots(castle.id) == []
    end

    test "records a live unit id per summoned slot" do
      castle = fixture_castle(9_002, "test_map", 7_000)

      stub(Coordinator, :summon_mob, fn _map, mob_id, x, y, _opts ->
        {:ok, mob_id * 1_000 + x + y}
      end)

      assert :ok = Treasure.spawn_daily(castle)
      assert Enum.sort(Treasure.live_slots(castle.id)) == [0, 1, 2, 3]
    end

    test "does not resummon slots already live" do
      castle = fixture_castle(9_003, "test_map", 7_000)

      stub(Coordinator, :summon_mob, fn _map, mob_id, x, y, _opts ->
        {:ok, mob_id * 1_000 + x + y}
      end)

      :ok = Treasure.spawn_daily(castle)

      stub(Coordinator, :summon_mob, fn _, _, _, _, _ ->
        raise "should not summon an already-live slot"
      end)

      assert :ok = Treasure.spawn_daily(castle)
      assert Enum.sort(Treasure.live_slots(castle.id)) == [0, 1, 2, 3]
    end
  end

  describe "spawn_all/0" do
    test "spawns treasure only for owned castles" do
      [castle_a, castle_b | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle_a.id => row(10)})

      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        {:ok, System.unique_integer([:positive])}
      end)

      assert :ok = Treasure.spawn_all()

      assert length(Treasure.live_slots(castle_a.id)) == 4
      assert Treasure.live_slots(castle_b.id) == []
    end
  end

  describe "release/1" do
    test "removes exactly the matching unit id" do
      table = EtsTable.table_for(:castle_treasure)
      :ets.insert(table, {{1, 3}, 555})
      :ets.insert(table, {{1, 7}, 556})

      assert :ok = Treasure.release(555)

      assert Treasure.live_slots(1) == [7]
    end
  end

  describe "live_slots/1" do
    test "reflects inserts for the given castle" do
      table = EtsTable.table_for(:castle_treasure)
      :ets.insert(table, {{1, 3}, 555})
      :ets.insert(table, {{1, 7}, 556})
      :ets.insert(table, {{2, 0}, 999})

      assert Enum.sort(Treasure.live_slots(1)) == [3, 7]
      assert Treasure.live_slots(2) == [0]
    end
  end
end
