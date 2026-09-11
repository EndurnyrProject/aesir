defmodule Aesir.ZoneServer.Mmo.Woe.LifecycleCaptureTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  import Aesir.TestWait
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Server
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

    Mimic.copy(Persistence)
    Mimic.allow(Coordinator, self(), server)
    Mimic.allow(Announcement, self(), server)
    Mimic.allow(MobSupervisor, self(), server)
    Mimic.allow(Persistence, self(), server)
    Mimic.allow(Manager, self(), server)

    :ok
  end

  test "sampled eligible credit captures after the killer logs out and warps" do
    Application.put_env(:zone_server, :woe_emperium_respawn_ms, 50)
    on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

    test_pid = self()

    stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
      unit_id = System.unique_integer([:positive])
      send(test_pid, {:summon, map, mob_id, x, y, opts, unit_id})
      {:ok, unit_id}
    end)

    stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts.text}) end)

    stub(Manager, :get, fn guild_id ->
      {:ok,
       %State{
         guild_id: guild_id,
         name: "TestGuild",
         master_char_id: 501,
         learned_skills: %{@approval_skill_id => 1}
       }}
    end)

    expect(Persistence, :persist, 1, fn castle_id, guild_id ->
      send(test_pid, {:persist, castle_id, guild_id})
      :ok
    end)

    stub(Persistence, :persist_economy, fn _castle_id, _state -> :ok end)

    castle = hd(CastleDb.all())
    castle_id = castle.id
    castle_map = castle.map

    assert :ok = Server.start()
    for _ <- CastleDb.all(), do: assert_receive({:summon, _, _, _, _, _, _}, 200)
    assert_receive {:announcement, "WoE has begun"}, 200

    old_unit_id = CastleStore.get(castle_id).emperium_unit_id
    :ok = UnitRegistry.register_unit(:player, 501, Map, %{map_name: castle_map}, self())

    assert :ok =
             Lifecycle.publish_death(:mob, old_unit_id, castle_map, %{
               attacker: {:player, 501},
               character_id: 501,
               guild_id: 7
             })

    :ok = UnitRegistry.unregister_unit(:player, 501)
    assert :ok = Lifecycle.publish_transition(:player, 501, castle_map, "prontera")

    assert_eventually(fn -> CastleStore.owner(castle_id) == 7 end)
    assert CastleStore.get(castle_id).epoch == 1
    assert_receive {:persist, ^castle_id, 7}, 200
    assert_receive {:announcement, conquest}, 200
    assert conquest == "#{castle.name} conquered by TestGuild"

    assert_receive {:summon, ^castle_map, @emperium_mob_id, _, _, _, new_unit_id}, 500
    refute new_unit_id == old_unit_id
    assert_eventually(fn -> CastleStore.get(castle_id).emperium_unit_id == new_unit_id end)
  end

  test "nil, ineligible, and owner credit retain ownership and re-arm each objective" do
    Application.put_env(:zone_server, :woe_emperium_respawn_ms, 20)
    on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

    test_pid = self()
    stub_summons(test_pid)
    stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts.text}) end)
    reject(&Persistence.persist/2)

    stub(Manager, :get, fn 7 ->
      {:ok, %State{guild_id: 7, name: "NoApproval", master_char_id: 501}}
    end)

    castle = hd(CastleDb.all())

    :ok =
      CastleStore.hydrate(%{
        castle.id => %{
          guild_id: 9,
          economy: 0,
          defense: 0,
          invested_economy: 0,
          invested_defense: 0
        }
      })

    assert :ok = Server.start()
    drain_summons(length(CastleDb.all()))
    assert_receive {:announcement, "WoE has begun"}, 200

    log =
      capture_log(fn ->
        first_unit_id = CastleStore.get(castle.id).emperium_unit_id
        publish_break(castle, first_unit_id, nil)
        second_unit_id = assert_rearmed(castle.id, first_unit_id, 1)

        publish_break(castle, second_unit_id, credit(7))
        third_unit_id = assert_rearmed(castle.id, second_unit_id, 2)

        publish_break(castle, third_unit_id, credit(9))
        _fourth_unit_id = assert_rearmed(castle.id, third_unit_id, 3)
      end)

    assert length(Regex.scan(~r/without eligible guild credit/, log)) == 3
    assert CastleStore.owner(castle.id) == 9
    refute_receive {:announcement, _}, 100
  end

  test "only a matching claimed objective with invalid credit logs" do
    Application.put_env(:zone_server, :woe_emperium_respawn_ms, 20)
    on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

    test_pid = self()
    stub_summons(test_pid)
    stub(Announcement, :to_all, fn _opts -> :ok end)
    stub(Persistence, :persist, fn _castle_id, _guild_id -> :ok end)
    stub(Persistence, :persist_economy, fn _castle_id, _state -> :ok end)

    stub(Manager, :get, fn guild_id ->
      {:ok,
       %State{
         guild_id: guild_id,
         name: "Eligible",
         master_char_id: 501,
         learned_skills: %{@approval_skill_id => 1}
       }}
    end)

    castle = hd(CastleDb.all())
    assert :ok = Server.start()
    drain_summons(length(CastleDb.all()))
    live_unit_id = CastleStore.get(castle.id).emperium_unit_id

    log =
      capture_log(fn ->
        assert :ok = Lifecycle.publish_death(:player, live_unit_id, castle.map, credit(7))
        publish_break(castle, live_unit_id + 1, nil)
        publish_break(castle, live_unit_id, credit(7))
        replacement_id = assert_rearmed(castle.id, live_unit_id, 1)
        publish_break(castle, live_unit_id, nil)
        publish_break(castle, replacement_id, credit(7))
        ended_unit_id = assert_rearmed(castle.id, replacement_id, 2)
        assert :ok = Server.stop()
        publish_break(castle, ended_unit_id, nil)
        refute Server.active?()
      end)

    assert length(Regex.scan(~r/without eligible guild credit/, log)) == 1
  end

  test "player collisions, non-deaths, stale units, and duplicate deaths cannot claim" do
    Application.put_env(:zone_server, :woe_emperium_respawn_ms, 50)
    on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

    test_pid = self()
    stub_summons(test_pid)
    stub(Announcement, :to_all, fn opts -> send(test_pid, {:announcement, opts.text}) end)
    reject(&Persistence.persist/2)

    castle = hd(CastleDb.all())

    assert :ok = Server.start()
    drain_summons(length(CastleDb.all()))
    assert_receive {:announcement, "WoE has begun"}, 200

    live_unit_id = CastleStore.get(castle.id).emperium_unit_id
    credit = credit(7)

    assert :ok = Lifecycle.publish_death(:player, live_unit_id, castle.map, credit)

    assert :ok =
             Lifecycle.publish(%Lifecycle.Event{
               unit_type: :mob,
               unit_id: live_unit_id,
               reason: :warp,
               old_map: castle.map,
               new_map: "prontera",
               kill_credit: credit
             })

    publish_break(castle, live_unit_id + 1, credit)
    assert Server.active?()
    assert CastleStore.get(castle.id).epoch == 0
    assert CastleStore.get(castle.id).emperium_unit_id == live_unit_id

    publish_break(castle, live_unit_id, nil)
    publish_break(castle, live_unit_id, credit)

    replacement_id = assert_rearmed(castle.id, live_unit_id, 1)
    assert_receive {:summon, _, @emperium_mob_id, _, _, _, ^replacement_id}, 200
    refute_receive {:summon, _, _, _, _, _, _}, 100
  end

  test "a stale timer token cannot consume the current replacement timer" do
    Application.put_env(:zone_server, :woe_emperium_respawn_ms, 75)
    on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

    test_pid = self()
    stub_summons(test_pid)
    stub(Announcement, :to_all, fn _opts -> :ok end)
    reject(&Persistence.persist/2)

    castle = hd(CastleDb.all())

    assert :ok = Server.start()
    drain_summons(length(CastleDb.all()))
    live_unit_id = CastleStore.get(castle.id).emperium_unit_id

    publish_break(castle, live_unit_id, nil)
    assert_eventually(fn -> CastleStore.get(castle.id).epoch == 1 end)

    [{server, _value}] = Registry.lookup(Aesir.ZoneServer.ProcessRegistry, Server)
    send(server, {:respawn_emperium, castle.id, 1, make_ref()})

    _replacement_id = assert_rearmed(castle.id, live_unit_id, 1)
  end

  test "AgitEnd rejects the ended objective and invalidates its pending timer across restart" do
    Application.put_env(:zone_server, :woe_emperium_respawn_ms, 150)
    on_exit(fn -> Application.delete_env(:zone_server, :woe_emperium_respawn_ms) end)

    test_pid = self()
    stub_summons(test_pid)
    stub(Announcement, :to_all, fn _opts -> :ok end)
    reject(&Persistence.persist/2)

    castle = hd(CastleDb.all())

    assert :ok = Server.start()
    drain_summons(length(CastleDb.all()))
    ended_unit_id = CastleStore.get(castle.id).emperium_unit_id

    publish_break(castle, ended_unit_id, nil)
    assert_eventually(fn -> CastleStore.get(castle.id).epoch == 1 end)

    assert :ok = Server.stop()
    publish_break(castle, ended_unit_id, credit(7))
    assert :ok = Server.start()
    drain_summons(length(CastleDb.all()))

    restarted_unit_id = CastleStore.get(castle.id).emperium_unit_id
    castle_map = castle.map
    assert restarted_unit_id != ended_unit_id
    assert CastleStore.get(castle.id).epoch == 2

    refute_receive {:summon, ^castle_map, @emperium_mob_id, _, _, _, _}, 300
    assert CastleStore.get(castle.id).emperium_unit_id == restarted_unit_id
  end

  defp stub_summons(test_pid) do
    stub(Coordinator, :summon_mob, fn map, mob_id, x, y, opts ->
      unit_id = System.unique_integer([:positive])
      send(test_pid, {:summon, map, mob_id, x, y, opts, unit_id})
      {:ok, unit_id}
    end)
  end

  defp drain_summons(count) do
    for _ <- 1..count, do: assert_receive({:summon, _, _, _, _, _, _}, 200)
  end

  defp publish_break(castle, unit_id, kill_credit) do
    assert :ok = Lifecycle.publish_death(:mob, unit_id, castle.map, kill_credit)
  end

  defp assert_rearmed(castle_id, old_unit_id, epoch) do
    assert_eventually(fn ->
      state = CastleStore.get(castle_id)

      state.epoch == epoch and is_integer(state.emperium_unit_id) and
        state.emperium_unit_id != old_unit_id
    end)

    CastleStore.get(castle_id).emperium_unit_id
  end

  defp credit(guild_id) do
    %{attacker: {:player, 501}, character_id: 501, guild_id: guild_id}
  end
end
