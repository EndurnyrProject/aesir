defmodule Aesir.ZoneServer.Mmo.Woe.GuardiansTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Guardians
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @mob_ids %{archer: 1285, knight: 1286, soldier: 1287}

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok
  end

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{guild_id: guild_id, economy: 0, defense: 0, invested_economy: 0, invested_defense: 0},
      overrides
    )
  end

  defp fixture_guild(id, skills \\ %{}) do
    %GuildState{guild_id: id, name: "Test Guild", master_char_id: 1, learned_skills: skills}
  end

  defp researched_guild(id), do: fixture_guild(id, %{10_002 => 1})

  describe "hire_cost/0" do
    test "is 10_000" do
      assert Guardians.hire_cost() == 10_000
    end
  end

  describe "hire_check/3" do
    setup do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      %{castle: castle}
    end

    test "not_owner when the guild does not hold the castle", %{castle: castle} do
      assert Guardians.hire_check(castle.id, 0, 2) == {:error, :not_owner}
    end

    test "research_required when the guild has no Guardian Research", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:error, :not_found} end)
      assert Guardians.hire_check(castle.id, 0, 1) == {:error, :research_required}
    end

    test "research_required when the guild's skill level is below 1", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:ok, fixture_guild(1)} end)
      assert Guardians.hire_check(castle.id, 0, 1) == {:error, :research_required}
    end

    test "invalid_slot when the slot is not an integer in 0..7", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:ok, researched_guild(1)} end)
      assert Guardians.hire_check(castle.id, 8, 1) == {:error, :invalid_slot}
      assert Guardians.hire_check(castle.id, "0", 1) == {:error, :invalid_slot}
    end

    test "already_hired when the slot is already hired", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:ok, researched_guild(1)} end)
      :ok = CastleStore.put_guardians(castle.id, [0])
      assert Guardians.hire_check(castle.id, 0, 1) == {:error, :already_hired}
    end

    test "ok when owned, researched, valid, and free", %{castle: castle} do
      stub(GuildManager, :get, fn 1 -> {:ok, researched_guild(1)} end)
      assert Guardians.hire_check(castle.id, 3, 1) == :ok
    end
  end

  describe "hire/3" do
    test "stores and persists the sorted slot list" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      stub(GuildManager, :get, fn 1 -> {:ok, researched_guild(1)} end)

      test_pid = self()

      stub(Persistence, :persist_guardians, fn castle_id, guardians ->
        send(test_pid, {:persisted, castle_id, guardians})
        :ok
      end)

      :ok = CastleStore.put_guardians(castle.id, [5])

      assert Guardians.hire(castle.id, 2, 1) == :ok
      assert CastleStore.guardians(castle.id) == [2, 5]

      castle_id = castle.id
      assert_receive {:persisted, ^castle_id, [2, 5]}
    end

    test "does not spawn outside a siege" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      stub(GuildManager, :get, fn 1 -> {:ok, researched_guild(1)} end)
      stub(Persistence, :persist_guardians, fn _, _ -> :ok end)
      stub(Coordinator, :summon_mob, fn _, _, _, _, _ -> raise "should not summon" end)

      assert Guardians.hire(castle.id, 2, 1) == :ok
    end

    test "spawns the slot exactly once when the castle is under siege" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      :ok = CastleStore.set_siege(castle.id, true)
      stub(GuildManager, :get, fn 1 -> {:ok, researched_guild(1)} end)
      stub(Persistence, :persist_guardians, fn _, _ -> :ok end)

      slot_def = Enum.at(castle.guardians, 2)
      mob_id = Map.fetch!(@mob_ids, slot_def.type)
      {x, y} = slot_def.cell
      test_pid = self()

      stub(Coordinator, :summon_mob, fn _map, ^mob_id, ^x, ^y, _opts ->
        send(test_pid, :summoned)
        {:ok, 55_555}
      end)

      assert Guardians.hire(castle.id, 2, 1) == :ok
      assert_receive :summoned
      assert Guardians.live_slots(castle.id) == [2]
    end

    test "returns the hire_check error unchanged" do
      [castle | _] = CastleDb.all()
      assert Guardians.hire(castle.id, 0, 999) == {:error, :not_owner}
    end
  end

  describe "summon_opts/5" do
    test "guardup 0 yields only guild_id" do
      slot = %{type: :soldier, cell: {60, 60}}
      assert Guardians.summon_opts(slot, 100, 0, 7, :renewal) == [guild_id: 7]
    end

    test "guardup 1 at defense 100 in renewal scales hp and stats" do
      slot = %{type: :soldier, cell: {60, 60}}
      {:ok, mob} = Mobs.by_id(1_287)

      opts = Guardians.summon_opts(slot, 100, 1, 7, :renewal)

      assert Keyword.get(opts, :guild_id) == 7
      assert Keyword.get(opts, :hp_override) == mob.hp + 1_000 + 100_000
      assert Keyword.get(opts, :stat_bonus) == %{def: 34, mdef: 34, atk: 10, aspd_rate: 5}
    end

    test "guardup 1 at defense 100 in pre-renewal scales hp" do
      slot = %{type: :soldier, cell: {60, 60}}
      {:ok, mob} = Mobs.by_id(1_287)

      opts = Guardians.summon_opts(slot, 100, 1, 7, :pre_renewal)

      assert Keyword.get(opts, :hp_override) == mob.hp + 200_000
    end

    test "guardup 3 scales atk and aspd_rate further" do
      slot = %{type: :soldier, cell: {60, 60}}

      opts = Guardians.summon_opts(slot, 100, 3, 7, :renewal)
      stat_bonus = Keyword.get(opts, :stat_bonus)

      assert stat_bonus.atk == 14
      assert stat_bonus.aspd_rate == 9
    end
  end

  describe "spawn_all/1" do
    test "summons enabled slots not already live, skipping one already live" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      :ok = CastleStore.put_guardians(castle.id, [0, 1])
      :ets.insert(EtsTable.table_for(:castle_guardians), {{castle.id, 1}, 999})
      stub(GuildManager, :get, fn 1 -> {:error, :not_found} end)

      test_pid = self()

      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        send(test_pid, :summoned)
        {:ok, System.unique_integer([:positive])}
      end)

      assert Guardians.spawn_all(castle) == :ok
      assert_receive :summoned
      assert Enum.sort(Guardians.live_slots(castle.id)) == [0, 1]
    end

    test "an unowned castle summons nothing" do
      [castle | _] = CastleDb.all()
      stub(Coordinator, :summon_mob, fn _, _, _, _, _ -> raise "should not summon" end)

      assert Guardians.spawn_all(castle) == :ok
      assert Guardians.live_slots(castle.id) == []
    end

    test "a summon error logs and leaves no row" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      :ok = CastleStore.put_guardians(castle.id, [0])
      stub(GuildManager, :get, fn 1 -> {:error, :not_found} end)
      stub(Coordinator, :summon_mob, fn _, _, _, _, _ -> {:error, :map_not_found} end)

      assert Guardians.spawn_all(castle) == :ok
      assert Guardians.live_slots(castle.id) == []
    end
  end

  describe "despawn_all/1" do
    test "unregisters and terminates each live unit and empties the rows" do
      [castle | _] = CastleDb.all()
      table = EtsTable.table_for(:castle_guardians)
      :ets.insert(table, {{castle.id, 0}, 111})
      :ets.insert(table, {{castle.id, 1}, 222})

      stub(UnitRegistry, :get_unit, fn
        :mob, 111 -> {:ok, {SomeMobModule, %{}, self()}}
        :mob, 222 -> {:error, :not_found}
      end)

      expect(UnitRegistry, :unregister_unit, 1, fn :mob, 111 -> :ok end)
      expect(MobSupervisor, :terminate_mob, 1, fn map, _pid -> {:ok, map} end)

      assert Guardians.despawn_all(castle) == :ok
      assert Guardians.live_slots(castle.id) == []
    end
  end

  describe "release/1" do
    test "removes exactly the matching row" do
      table = EtsTable.table_for(:castle_guardians)
      :ets.insert(table, {{1, 3}, 555})
      :ets.insert(table, {{1, 7}, 556})

      assert Guardians.release(555) == {:ok, {1, 3}}
      assert Guardians.live_slots(1) == [7]
      assert Guardians.release(555) == :error
    end
  end

  describe "clear_slot/2" do
    test "removes the slot and persists" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.put_guardians(castle.id, [0, 3])

      test_pid = self()

      stub(Persistence, :persist_guardians, fn castle_id, guardians ->
        send(test_pid, {:persisted, castle_id, guardians})
        :ok
      end)

      assert Guardians.clear_slot(castle.id, 3) == :ok
      assert CastleStore.guardians(castle.id) == [0]

      castle_id = castle.id
      assert_receive {:persisted, ^castle_id, [0]}
    end
  end

  describe "on_conquest/2" do
    test "a researched guild despawns and respawns the same slots" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(2)})
      :ok = CastleStore.put_guardians(castle.id, [0, 2])
      stub(GuildManager, :get, fn 2 -> {:ok, researched_guild(2)} end)

      stub(Coordinator, :summon_mob, fn _, _, _, _, _ ->
        {:ok, System.unique_integer([:positive])}
      end)

      assert Guardians.on_conquest(castle, 2) == :ok
      assert Enum.sort(Guardians.live_slots(castle.id)) == [0, 2]
      assert CastleStore.guardians(castle.id) == [0, 2]
    end

    test "an unresearched guild despawns, clears, and persists an empty list" do
      [castle | _] = CastleDb.all()
      :ok = CastleStore.hydrate(%{castle.id => row(2)})
      :ok = CastleStore.put_guardians(castle.id, [0, 2])
      table = EtsTable.table_for(:castle_guardians)
      :ets.insert(table, {{castle.id, 0}, 111})

      stub(UnitRegistry, :get_unit, fn :mob, 111 -> {:error, :not_found} end)
      stub(GuildManager, :get, fn 2 -> {:error, :not_found} end)

      test_pid = self()

      stub(Persistence, :persist_guardians, fn castle_id, guardians ->
        send(test_pid, {:persisted, castle_id, guardians})
        :ok
      end)

      assert Guardians.on_conquest(castle, 2) == :ok
      assert Guardians.live_slots(castle.id) == []
      assert CastleStore.guardians(castle.id) == []

      castle_id = castle.id
      assert_receive {:persisted, ^castle_id, []}
    end
  end
end
