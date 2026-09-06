defmodule Aesir.ZoneServer.Mmo.Woe.ServerTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @emperium_mob_id 1288

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok = MapFlags.reload()

    server = start_supervised!(Server)

    Mimic.allow(Coordinator, self(), server)
    Mimic.allow(Announcement, self(), server)
    Mimic.allow(MobSupervisor, self(), server)

    :ok
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

      expect(Announcement, :to_all, 1, fn opts ->
        send(test_pid, {:announcement, opts})
        :ok
      end)

      assert :ok = Server.start()
      assert Server.active?()

      for castle <- CastleDb.all() do
        assert MapFlags.get(castle.map, :gvg)
        assert CastleStore.get(castle.id).siege_active?

        assert_receive {:summon, map, @emperium_mob_id, x, y, []}, 200
        assert map == castle.map
        assert {x, y} == castle.emperium
        refute is_nil(CastleStore.get(castle.id).emperium_unit_id)
      end

      assert_receive {:announcement, opts}, 200
      assert opts.text == "WoE has begun"
      assert opts.color == woe_color()
      assert opts.style == :TOP
    end

    test "is idempotent" do
      expect(Coordinator, :summon_mob, castle_count(), fn _, _, _, _, [] -> {:ok, 1} end)
      expect(Announcement, :to_all, 1, fn _opts -> :ok end)

      assert :ok = Server.start()
      assert :ok = Server.start()
      assert Server.active?()
    end

    test "skips a castle whose Emperium summon fails, leaving it non-gvg and inactive" do
      [failed_castle | rest] = CastleDb.all()
      ok_castle = hd(rest)

      expect(Coordinator, :summon_mob, castle_count(), fn map, _, _, _, [] ->
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

      assert :ok = Server.start()
      for _ <- 1..castle_count(), do: assert_receive({:summon, _, _, _, _, []}, 200)
      assert_receive {:announcement, "WoE has begun"}, 200

      expect(MobSupervisor, :terminate_mob, castle_count(), fn map, pid ->
        assert pid == self()
        send(test_pid, {:despawn, map})
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
      end

      assert_receive {:announcement, "WoE has ended"}, 200

      for castle <- CastleDb.all() do
        assert_receive {:announcement, text}, 200
        assert text =~ castle.name
        assert text =~ "unoccupied"
      end
    end

    test "is idempotent" do
      stub(Coordinator, :summon_mob, fn _, _, _, _, [] -> {:ok, 1} end)
      stub(Announcement, :to_all, fn _opts -> :ok end)

      assert :ok = Server.start()
      expect(Announcement, :to_all, 1 + castle_count(), fn _opts -> :ok end)

      assert :ok = Server.stop()
      assert :ok = Server.stop()
      refute Server.active?()
    end
  end
end
