defmodule Aesir.ZoneServer.Mmo.Woe.ServerTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  import Aesir.TestWait

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Mmo.Woe.Guardians
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Mmo.Woe.Services
  alias Aesir.ZoneServer.Mmo.Woe.Treasure
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @approval_skill_id 10_000
  @emperium_mob_id 1288

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok = MapFlags.reload()

    server = start_supervised!(Server)

    Mimic.allow(Coordinator, self(), server)
    Mimic.allow(Announcement, self(), server)
    Mimic.allow(MobSupervisor, self(), server)
    Mimic.allow(Manager, self(), server)
    Mimic.allow(Persistence, self(), server)
    Mimic.allow(Guardians, self(), server)
    Mimic.allow(Services, self(), server)

    {:ok, server: server}
  end

  defp castle_count, do: length(CastleDb.all())

  defp woe_color do
    {:ok, flag} = Flags.value("bc_woe")
    Flags.decode(flag, 0).color
  end

  describe "start/0" do
    test "arms every castle without an NPC owner event and broadcasts the WoE begun message" do
      test_pid = self()

      expect(Coordinator, :summon_mob, castle_count(), fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, System.unique_integer([:positive])}
      end)

      expect(Guardians, :spawn_all, castle_count(), fn castle ->
        send(test_pid, {:guardians_spawn, castle.id})
        :ok
      end)

      expect(Announcement, :to_all, 1, fn opts ->
        send(test_pid, {:announcement, opts})
        :ok
      end)

      assert :ok = Server.start()
      assert Server.active?()

      for castle <- CastleDb.all() do
        assert MapFlags.get(castle.map, :gvg)
        assert CastleStore.get(castle.id).siege_active?

        expected_opts =
          Economy.emperium_summon_opts(CastleStore.economy(castle.id).defense, GameMode.mode())

        assert_receive {:summon, map, @emperium_mob_id, x, y, ^expected_opts}, 200
        assert map == castle.map
        assert {x, y} == castle.emperium
        refute is_nil(CastleStore.get(castle.id).emperium_unit_id)

        assert_receive {:guardians_spawn, castle_id}, 200
        assert castle_id == castle.id
      end

      assert_receive {:announcement, opts}, 200
      assert opts.text == "WoE has begun"
      assert opts.color == woe_color()
      assert opts.style == :TOP
    end

    test "is idempotent" do
      expect(Coordinator, :summon_mob, castle_count(), fn _, _, _, _, _opts -> {:ok, 1} end)
      expect(Announcement, :to_all, 1, fn _opts -> :ok end)

      assert :ok = Server.start()
      assert :ok = Server.start()
      assert Server.active?()
    end

    test "skips a castle whose Emperium summon fails, leaving it non-gvg and inactive" do
      [failed_castle | rest] = CastleDb.all()
      ok_castle = hd(rest)

      expect(Coordinator, :summon_mob, castle_count(), fn map, _, _, _, _opts ->
        if map == failed_castle.map do
          {:error, :map_not_found}
        else
          {:ok, System.unique_integer([:positive])}
        end
      end)

      expect(Guardians, :spawn_all, castle_count() - 1, fn _castle -> :ok end)
      expect(Announcement, :to_all, 1, fn _opts -> :ok end)

      assert :ok = Server.start()
      assert Server.active?()

      refute MapFlags.get(failed_castle.map, :gvg)
      refute CastleStore.get(failed_castle.id).siege_active?
      assert is_nil(CastleStore.get(failed_castle.id).emperium_unit_id)

      assert MapFlags.get(ok_castle.map, :gvg)
      assert CastleStore.get(ok_castle.id).siege_active?
      refute is_nil(CastleStore.get(ok_castle.id).emperium_unit_id)
    end
  end

  describe "stop/0" do
    test "clears gvg, despawns live Emperiums, and broadcasts the end and roll-call" do
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
        unit_id = System.unique_integer([:positive])
        :ok = UnitRegistry.register_unit(:mob, unit_id, Map, %{}, self())
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, unit_id}
      end)

      stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts.text}) end)

      stub(Guardians, :spawn_all, fn _castle -> :ok end)

      assert :ok = Server.start()
      for _ <- 1..castle_count(), do: assert_receive({:summon, _, _, _, _, _}, 200)
      assert_receive {:announcement, "WoE has begun"}, 200

      expect(MobSupervisor, :terminate_mob, castle_count(), fn map, pid ->
        assert pid == self()
        send(test_pid, {:despawn, map})
        :ok
      end)

      expect(Guardians, :despawn_all, castle_count(), fn castle ->
        send(test_pid, {:guardians_despawn, castle.id})
        :ok
      end)

      assert :ok = Server.stop()
      refute Server.active?()

      for castle <- CastleDb.all() do
        refute MapFlags.get(castle.map, :gvg)
        refute CastleStore.get(castle.id).siege_active?
        assert is_nil(CastleStore.get(castle.id).emperium_unit_id)
        assert_receive {:despawn, map}, 200
        assert map == castle.map
        assert_receive {:guardians_despawn, castle_id}, 200
        assert castle_id == castle.id
      end

      assert_receive {:announcement, "WoE has ended"}, 200

      for castle <- CastleDb.all() do
        assert_receive {:announcement, text}, 200
        assert text =~ castle.name
        assert text =~ "unoccupied"
      end
    end

    test "is idempotent" do
      stub(Coordinator, :summon_mob, fn _, _, _, _, _opts -> {:ok, 1} end)
      stub(Announcement, :to_all, fn _opts -> :ok end)

      assert :ok = Server.start()
      expect(Announcement, :to_all, 1 + castle_count(), fn _opts -> :ok end)

      assert :ok = Server.stop()
      assert :ok = Server.stop()
      refute Server.active?()
    end
  end

  describe "defense-scaled Emperium summon" do
    test "arms a defense-100 castle with the scaled stat bonus" do
      castle = hd(CastleDb.all())

      :ok =
        CastleStore.hydrate(%{
          castle.id => %{
            guild_id: nil,
            economy: 0,
            defense: 100,
            invested_economy: 0,
            invested_defense: 0
          }
        })

      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn _opts -> :ok end)

      assert :ok = Server.start()

      opts =
        Enum.find_value(1..castle_count(), fn _ ->
          assert_receive {:summon, map, @emperium_mob_id, _x, _y, opts}, 200
          if map == castle.map, do: opts
        end)

      assert Keyword.fetch!(opts, :stat_bonus) == %{def: 34, mdef: 34}
      assert is_integer(Keyword.fetch!(opts, :hp_override))
    end
  end

  describe "conquest applies the economy penalty" do
    test "captured castle's economy and defense drop by 5 and daily counters clear" do
      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn _opts -> :ok end)

      stub(Manager, :get, fn guild_id ->
        {:ok,
         %State{
           guild_id: guild_id,
           name: "TestGuild",
           master_char_id: 501,
           learned_skills: %{@approval_skill_id => 1}
         }}
      end)

      stub(Persistence, :persist, fn _castle_id, _guild_id -> :ok end)
      stub(Persistence, :persist_economy, fn _castle_id, _state -> :ok end)

      castle = hd(CastleDb.all())

      :ok =
        CastleStore.hydrate(%{
          castle.id => %{
            guild_id: 9,
            economy: 20,
            defense: 20,
            invested_economy: 1,
            invested_defense: 2
          }
        })

      assert :ok = Server.start()
      live_unit_id = CastleStore.get(castle.id).emperium_unit_id

      expect(Guardians, :on_conquest, 1, fn conquered_castle, guild_id ->
        assert conquered_castle.id == castle.id
        assert guild_id == 7

        assert CastleStore.economy(castle.id) == %{
                 economy: 15,
                 defense: 15,
                 invested_economy: 0,
                 invested_defense: 0
               }

        :ok
      end)

      expect(Services, :on_conquest, 1, fn conquered_castle ->
        assert conquered_castle.id == castle.id
        :ok
      end)

      assert :ok =
               Lifecycle.publish_death(:mob, live_unit_id, castle.map, %{
                 attacker: {:player, 501},
                 character_id: 501,
                 guild_id: 7
               })

      assert_eventually(fn -> CastleStore.owner(castle.id) == 7 end)

      assert CastleStore.economy(castle.id) == %{
               economy: 15,
               defense: 15,
               invested_economy: 0,
               invested_defense: 0
             }
    end
  end

  describe "retained ownership skips guardian transfer" do
    test "an Emperium break without eligible guild credit never calls Guardians.on_conquest/2" do
      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn _opts -> :ok end)
      stub(Guardians, :spawn_all, fn _castle -> :ok end)
      reject(&Guardians.on_conquest/2)

      castle = hd(CastleDb.all())
      assert :ok = Server.start()
      live_unit_id = CastleStore.get(castle.id).emperium_unit_id

      assert :ok =
               Lifecycle.publish_death(:mob, live_unit_id, castle.map, %{
                 attacker: {:player, 501},
                 character_id: 501
               })

      assert_eventually(fn -> is_nil(CastleStore.get(castle.id).emperium_unit_id) end)
      assert is_nil(CastleStore.owner(castle.id))
    end
  end

  describe "guardian death releases its slot" do
    test "clears the guardian slot and never attempts an Emperium claim", %{server: server} do
      test_pid = self()

      Mimic.allow(CastleStore, self(), server)
      reject(&CastleStore.claim_break/3)

      castle = hd(CastleDb.all())
      guardian_unit_id = System.unique_integer([:positive])

      expect(Guardians, :release, fn unit_id ->
        assert unit_id == guardian_unit_id
        {:ok, {castle.id, 3}}
      end)

      expect(Guardians, :clear_slot, fn castle_id, slot ->
        send(test_pid, {:clear_slot, castle_id, slot})
        :ok
      end)

      assert :ok =
               Lifecycle.publish_death(:mob, guardian_unit_id, castle.map, %{
                 attacker: {:player, 501},
                 character_id: 501,
                 guild_id: 7
               })

      assert_receive {:clear_slot, castle_id, slot}, 200
      assert castle_id == castle.id
      assert slot == 3

      assert is_nil(CastleStore.owner(castle.id))
    end
  end

  describe "treasure release on lifecycle events" do
    test "termination on a castle map releases a live treasure slot" do
      castle = hd(CastleDb.all())
      :ets.insert(EtsTable.table_for(:castle_treasure), {{castle.id, 3}, 9_001})

      assert :ok = Lifecycle.publish_departure(:mob, 9_001, castle.map, :termination)

      assert_eventually(fn -> Treasure.live_slots(castle.id) == [] end)
    end

    test "death releases a live treasure slot and still reaches the Emperium path" do
      stub(Coordinator, :summon_mob, fn _map, _mob_id, _x, _y, _opts ->
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn _opts -> :ok end)

      stub(Manager, :get, fn guild_id ->
        {:ok,
         %State{
           guild_id: guild_id,
           name: "TestGuild",
           master_char_id: 501,
           learned_skills: %{@approval_skill_id => 1}
         }}
      end)

      stub(Persistence, :persist, fn _castle_id, _guild_id -> :ok end)
      stub(Persistence, :persist_economy, fn _castle_id, _state -> :ok end)
      stub(Guardians, :on_conquest, fn _castle, _guild_id -> :ok end)
      stub(Services, :on_conquest, fn _castle -> :ok end)

      castle = hd(CastleDb.all())
      assert :ok = Server.start()
      live_unit_id = CastleStore.get(castle.id).emperium_unit_id

      :ets.insert(EtsTable.table_for(:castle_treasure), {{castle.id, 5}, live_unit_id})

      assert :ok =
               Lifecycle.publish_death(:mob, live_unit_id, castle.map, %{
                 attacker: {:player, 501},
                 character_id: 501,
                 guild_id: 7
               })

      assert_eventually(fn -> CastleStore.owner(castle.id) == 7 end)
      assert Treasure.live_slots(castle.id) == []
    end
  end
end
