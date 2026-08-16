defmodule Aesir.ZoneServer.Mmo.Woe.ServerTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestWait

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor

  @emperium_mob_id 1288
  @emperium_event "WoeController::OnEmperiumBreak"

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok = MapFlags.reload()

    server = start_supervised!(Server)

    Mimic.copy(Persistence)
    Mimic.allow(Coordinator, self(), server)
    Mimic.allow(Announcement, self(), server)
    Mimic.allow(MobSupervisor, self(), server)
    Mimic.allow(Persistence, self(), server)
    Mimic.allow(Manager, self(), server)

    :ok
  end

  defp castle_count, do: length(CastleDb.all())

  defp woe_color do
    {:ok, flag} = Flags.value("bc_woe")
    Flags.decode(flag, 0).color
  end

  defp summon_stub(test_pid) do
    stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
      send(test_pid, {:summon, map, mob_id, x, y, opts})
      {:ok, System.unique_integer([:positive])}
    end)
  end

  defp guild_stub do
    stub(Manager, :get, fn _guild_id ->
      {:ok, %State{name: "TestGuild", guild_id: 7, master_char_id: 501}}
    end)
  end

  defp drain_summons(count) do
    for _ <- 1..count, do: assert_receive({:summon, _, _, _, _, _}, 200)
  end

  describe "start/0" do
    test "arms every castle and broadcasts the WoE begun message" do
      test_pid = self()

      expect(Coordinator, :summon_mob, castle_count(), fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, System.unique_integer([:positive])}
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

        assert_receive {:summon, map, @emperium_mob_id, x, y, opts}, 200
        assert map == castle.map
        assert {x, y} == castle.emperium
        assert Keyword.get(opts, :event) == @emperium_event
        refute is_nil(CastleStore.get(castle.id).emperium_unit_id)
      end

      assert_receive {:announcement, opts}, 200
      assert opts.text == "WoE has begun"
      assert opts.color == woe_color()
      assert opts.style == :TOP
    end

    test "is idempotent" do
      expect(Coordinator, :summon_mob, castle_count(), fn _, _, _, _, _ -> {:ok, 1} end)
      expect(Announcement, :to_all, 1, fn _opts -> :ok end)

      assert :ok = Server.start()
      assert :ok = Server.start()
      assert Server.active?()
    end
  end

  describe "stop/0" do
    test "clears gvg, despawns emperiums, and broadcasts the end and roll-call" do
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts.text}) end)

      assert :ok = Server.start()
      for _ <- 1..castle_count(), do: assert_receive({:summon, _, _, _, _, _}, 200)
      assert_receive {:announcement, "WoE has begun"}, 200

      expect(MobSupervisor, :kill_by_event, castle_count(), fn map, event ->
        send(test_pid, {:despawn, map, event})
        :ok
      end)

      assert :ok = Server.stop()
      refute Server.active?()

      for castle <- CastleDb.all() do
        refute MapFlags.get(castle.map, :gvg)
        refute CastleStore.get(castle.id).siege_active?
        assert is_nil(CastleStore.get(castle.id).emperium_unit_id)

        assert_receive {:despawn, map, @emperium_event}, 200
        assert map == castle.map
      end

      assert_receive {:announcement, "WoE has ended"}, 200

      for castle <- CastleDb.all() do
        assert_receive {:announcement, text}, 200
        assert text =~ castle.name
        assert text =~ "unoccupied"
      end
    end

    test "is idempotent" do
      stub(Coordinator, :summon_mob, fn _, _, _, _, _ -> {:ok, 1} end)
      stub(Announcement, :to_all, fn _opts -> :ok end)

      assert :ok = Server.start()

      expect(MobSupervisor, :kill_by_event, castle_count(), fn _, _ -> :ok end)
      expect(Announcement, :to_all, 1 + castle_count(), fn _opts -> :ok end)

      assert :ok = Server.stop()
      assert :ok = Server.stop()
      refute Server.active?()
    end
  end

  describe "capture/4" do
    test "claims the castle, persists, broadcasts the conquest, and arms the respawn timer" do
      Application.put_env(:zone_server, :woe_emperium_respawn_ms, 50)
      on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

      test_pid = self()

      expect(Coordinator, :summon_mob, castle_count() + 1, fn map, mob_id, x, y, opts ->
        unit_id = System.unique_integer([:positive])
        send(test_pid, {:summon, map, mob_id, x, y, opts, unit_id})
        {:ok, unit_id}
      end)

      stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts}) end)

      expect(Manager, :get, 1, fn _guild_id ->
        {:ok, %State{name: "TestGuild", guild_id: 7, master_char_id: 501}}
      end)

      expect(Persistence, :persist, 1, fn castle_id, guild_id ->
        send(test_pid, {:persist, castle_id, guild_id})
        :ok
      end)

      castle = hd(CastleDb.all())
      castle_id = castle.id

      assert :ok = Server.start()
      for _ <- 1..castle_count(), do: assert_receive({:summon, _, _, _, _, _, _}, 200)
      assert_receive {:announcement, %{text: "WoE has begun"}}, 200

      assert {:ok, :captured} = Server.capture(castle_id, 0, 7, 501)

      assert CastleStore.owner(castle_id) == 7
      assert CastleStore.get(castle_id).epoch == 1

      assert_receive {:persist, ^castle_id, 7}, 200

      assert_receive {:announcement, %{text: text}}, 200
      assert text =~ castle.name
      assert text =~ "conquered by TestGuild"

      original_unit_id = CastleStore.get(castle_id).emperium_unit_id
      assert_receive {:summon, map, @emperium_mob_id, x, y, opts, new_unit_id}, 500
      assert map == castle.map
      assert {x, y} == castle.emperium
      assert Keyword.get(opts, :event) == @emperium_event
      refute new_unit_id == original_unit_id

      assert_eventually(fn -> CastleStore.get(castle_id).emperium_unit_id == new_unit_id end)
      refute_receive {:summon, _, _, _, _, _, _}, 100
    end

    test "rejects a stale epoch without side effects" do
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts}) end)

      expect(Manager, :get, 1, fn _guild_id ->
        {:ok, %State{name: "TestGuild", guild_id: 7, master_char_id: 501}}
      end)

      expect(Persistence, :persist, 1, fn castle_id, guild_id ->
        send(test_pid, {:persist, castle_id, guild_id})
        :ok
      end)

      castle = hd(CastleDb.all())
      castle_id = castle.id

      assert :ok = Server.start()
      for _ <- 1..castle_count(), do: assert_receive({:summon, _, _, _, _, _}, 200)
      assert_receive {:announcement, _}, 200

      assert {:ok, :captured} = Server.capture(castle_id, 0, 7, 501)
      assert_receive {:persist, ^castle_id, 7}, 200
      assert_receive {:announcement, %{text: text}}, 200
      assert text =~ "conquered by TestGuild"

      assert {:error, :stale_epoch} = Server.capture(castle_id, 0, 8, 502)
      assert CastleStore.owner(castle_id) == 7
      refute_receive {:persist, _, _}, 100
      refute_receive {:announcement, _}, 100
    end

    test "rejects capture on an ended siege without side effects" do
      test_pid = self()

      stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts}) end)
      reject(&Persistence.persist/2)

      castle = hd(CastleDb.all())
      castle_id = castle.id

      assert :ok = Server.start()
      for _ <- 1..castle_count(), do: assert_receive({:summon, _, _, _, _, _}, 200)
      assert_receive {:announcement, _}, 200

      expect(MobSupervisor, :kill_by_event, castle_count(), fn _, _ -> :ok end)

      assert :ok = Server.stop()
      for _ <- 1..(1 + castle_count()), do: assert_receive({:announcement, _}, 200)

      assert {:error, :not_active} = Server.capture(castle_id, 0, 8, 502)
      assert is_nil(CastleStore.owner(castle_id))
      refute_receive {:announcement, _}, 100
    end

    test "skips a castle whose emperium summon fails, leaving it non-gvg and not under siege" do
      test_pid = self()
      [failed_castle | rest] = CastleDb.all()
      ok_castle = hd(rest)

      expect(Coordinator, :summon_mob, castle_count(), fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})

        if map == failed_castle.map do
          {:error, :map_not_found}
        else
          {:ok, System.unique_integer([:positive])}
        end
      end)

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

    test "re-arming a castle's respawn timer cancels the previous timer" do
      Application.put_env(:zone_server, :woe_emperium_respawn_ms, 50)
      on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

      test_pid = self()

      expect(Coordinator, :summon_mob, castle_count() + 1, fn map, mob_id, x, y, opts ->
        send(test_pid, {:summon, map, mob_id, x, y, opts})
        {:ok, System.unique_integer([:positive])}
      end)

      stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts}) end)
      guild_stub()

      expect(Persistence, :persist, 2, fn castle_id, guild_id ->
        send(test_pid, {:persist, castle_id, guild_id})
        :ok
      end)

      castle = hd(CastleDb.all())
      castle_id = castle.id

      assert :ok = Server.start()
      drain_summons(castle_count())
      assert_receive {:announcement, %{text: "WoE has begun"}}, 200

      assert {:ok, :captured} = Server.capture(castle_id, 0, 7, 501)
      assert {:ok, :captured} = Server.capture(castle_id, 1, 7, 502)

      assert CastleStore.owner(castle_id) == 7
      assert CastleStore.get(castle_id).epoch == 2

      assert_receive {:persist, ^castle_id, 7}, 200
      assert_receive {:persist, ^castle_id, 7}, 200
      assert_receive {:announcement, _}, 200
      assert_receive {:announcement, _}, 200

      # Only the current capture's timer survives to respawn once; the re-armed
      # timer cancels the first.
      assert_receive {:summon, map, @emperium_mob_id, _, _, _}, 500
      assert map == castle.map
      refute_receive {:summon, _, _, _, _, _}, 150

      expect(MobSupervisor, :kill_by_event, castle_count(), fn _, _ -> :ok end)
      assert :ok = Server.stop()
      refute Server.active?()
      refute_receive {:summon, _, _, _, _, _}, 150
    end

    test "stop/0 cancels a pending respawn timer" do
      Application.put_env(:zone_server, :woe_emperium_respawn_ms, 200)
      on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

      test_pid = self()
      summon_stub(test_pid)
      stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts}) end)
      guild_stub()
      expect(Persistence, :persist, 1, fn _castle_id, _guild_id -> :ok end)

      castle = hd(CastleDb.all())

      assert :ok = Server.start()
      drain_summons(castle_count())
      assert_receive {:announcement, %{text: "WoE has begun"}}, 200

      assert {:ok, :captured} = Server.capture(castle.id, 0, 7, 501)
      assert_receive {:announcement, _}, 200

      expect(MobSupervisor, :kill_by_event, castle_count(), fn _, _ -> :ok end)
      assert :ok = Server.stop()
      refute Server.active?()

      # The pending 200ms respawn timer was cancelled: no summon after AgitEnd.
      refute_receive {:summon, _, _, _, _, _}, 400
    end
  end
end
