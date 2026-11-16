defmodule Aesir.ZoneServer.Unit.Mob.CombatHandlerCaptureTest do
  @moduledoc """
  A capture is the reference's `unit_remove_map(md, CLR_OUTSIGHT)` then
  `status_kill` (`mob_dead(md, nullptr, 3)`): no EXP and no drop roll, but the
  NPC death event, slave removal and respawn scheduling still follow, and the
  mob leaves its observers' sight instead of dying on screen.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Net.UnitDespawn
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}
  setup :setup_ets_tables

  setup do
    Mimic.copy(KillExp)
    test_pid = self()

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(test_pid, {:broadcast, packet})
      :ok
    end)

    stub(Coordinator, :mob_died, fn map, id, event_char_id ->
      send(test_pid, {:mob_died, map, id, event_char_id})
      :ok
    end)

    :ok
  end

  test "capturing a damaged mob rewards nothing, keeps its death event and respawn, and leaves sight" do
    reject(&KillExp.distribute_typed/7)
    register_player(42)
    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")

    state =
      build_mob_state()
      |> MobState.add_aggro(42, 300)
      |> MobState.add_typed_aggro({:player, 42}, 42, 300)
      |> MobState.set_owner_event("OwnerEventNpc::OnMyMobDead")

    assert {:reply, :ok, captured} = MobSession.handle_call({:combat, :capture}, self(), state)

    assert captured.is_dead
    assert_receive {:mob_died, "prontera", 1, 42}

    out_of_sight = DespawnReason.out_of_sight()
    assert_receive {:broadcast, %UnitDespawn{gid: 1, reason: ^out_of_sight}}
    refute_receive {:broadcast, %UnitDespawn{gid: 1}}
    refute_receive {:loot, _reward}
  end

  test "capturing an MVP plays the MVP effect for its top damage dealer with no MVP exp or drop" do
    test_pid = self()
    stub(Announcement, :to_all, fn opts -> send(test_pid, {:announced, opts}) end)
    register_player(42, "Tapper")
    register_player(43, "Bruiser")
    :ok = PubSub.subscribe(Aesir.PubSub, "player:43")

    base = build_mob_state()

    mvp_data = %{
      base.mob_data
      | name: "Bacsojin",
        mvp_exp: 1000,
        mvp_drops: [%MobDrop{item: "Jellopy", rate: 10_000}]
    }

    state =
      %{base | mob_data: mvp_data}
      |> MobState.add_aggro(42, 100)
      |> MobState.add_aggro(43, 500)

    assert {:reply, :ok, _captured} = MobSession.handle_call({:combat, :capture}, self(), state)

    assert_receive {:announced, %{text: "Bruiser has defeated Bacsojin!"}}
    refute_receive {:announced, _other}
    refute_receive {:progression, {:mob_kill_exp, _base, _job, _race, _class}}
    refute_receive {:loot, _reward}
  end

  test "capturing an undamaged event mob leaves its death event with no player to attach to" do
    state = MobState.set_owner_event(build_mob_state(), "OwnerEventNpc::OnMyMobDead")

    assert {:reply, :ok, _captured} = MobSession.handle_call({:combat, :capture}, self(), state)

    assert_receive {:mob_died, "prontera", 1, nil}
  end

  test "a player-owned non-player killing blow attaches the event to the loot leader" do
    register_player(42)
    register_player(43)
    attacker = %{build_mob_state() | instance_id: 2, owner_player_id: 43}
    UnitRegistry.register_unit(:mob, 2, MobState, attacker, self())

    state =
      build_mob_state()
      |> MobState.add_aggro(42, 900)
      |> MobState.add_typed_aggro({:player, 42}, 42, 900)
      |> MobState.set_owner_event("OwnerEventNpc::OnMyMobDead")

    assert {:noreply, _dead} = CombatHandler.handle_apply_damage(700, {:mob, 2}, state)
    assert_receive {:mob_died, "prontera", 1, 42}
  end

  test "capturing a dead mob is refused and changes nothing" do
    state = MobState.set_dead(build_mob_state())

    assert {:reply, {:error, :dead}, ^state} =
             MobSession.handle_call({:combat, :capture}, self(), state)

    refute_receive {:mob_died, _map, _id, _char_id}
    refute_receive {:broadcast, _packet}
  end

  defp register_player(char_id, name \\ "Player") do
    UnitRegistry.register_unit(
      :player,
      char_id,
      PlayerState,
      struct(PlayerState,
        character_id: char_id,
        character_name: name,
        map_name: "prontera",
        action_state: :idle,
        stats: %{current_state: %{hp: 100}, progression: %{base_level: 50}}
      ),
      self()
    )
  end

  defp build_mob_state do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      base_exp: 100,
      job_exp: 50,
      drops: [%MobDrop{item: "Jellopy", rate: 10_000}],
      modes: [],
      hp: 1000,
      sp: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      atk: 10,
      matk: 10,
      def: 0,
      mdef: 0,
      attack_range: 1,
      walk_speed: 400,
      attack_delay: 1872,
      attack_motion: 672,
      client_attack_motion: 672,
      damage_motion: 480,
      element: {:water, 1},
      race: :plant,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
    %{state | hp: 700, calculated: %{state.calculated | max_hp: 1000}}
  end
end
