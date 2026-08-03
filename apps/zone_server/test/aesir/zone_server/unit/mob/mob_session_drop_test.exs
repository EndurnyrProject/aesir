defmodule Aesir.ZoneServer.Unit.Mob.MobSessionDropTest do
  @moduledoc """
  Verifies that a mob death broadcasts the drop-rolling `:mob_killed` payload
  (drop table, mob level, death position -- no EXP fields, since EXP now
  flows through `Unit.Mob.KillExp.distribute/6` as `{:mob_kill_exp, ...}`) to
  the killer, and that a death with no killer produces no broadcast at all.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}
  setup :setup_ets_tables

  setup do
    Mimic.copy(Aesir.ZoneServer.Unit.Mob.KillExp)
  end

  test "killing a mob broadcasts the drop-rolling :mob_killed payload to the killer" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id, _killer -> :ok end)

    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")
    :ok = Lifecycle.subscribe()

    drops = [%MobDrop{item: "Red_Potion", rate: 10_000}]
    state = build_mob_state(hp: 1, max_hp: 1000, drops: drops)

    {:noreply, dead_state} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, state)

    assert_receive {:loot, {:mob_killed, payload}}
    assert payload.drops == drops
    assert payload.mob_level == 25
    assert payload.map == "prontera"
    assert payload.x == 100
    assert payload.y == 100
    assert payload.ownership == %LootOwnership{first: nil, second: nil, third: nil}
    assert payload.final_source == {:player, 42}
    refute payload.boss?

    assert_receive {:unit_lifecycle,
                    %Event{
                      unit_type: :mob,
                      unit_id: 1,
                      reason: :death,
                      old_map: "prontera",
                      new_map: nil
                    } = event}

    stub(SpatialIndex, :remove_unit, fn :mob, 1 -> :ok end)
    stub(Broadcast, :publish_mob_despawn, fn "prontera", 1 -> :ok end)

    assert :ok = MobSession.terminate(:normal, dead_state)
    refute_receive {:unit_lifecycle, ^event}
  end

  test "mob death ranks ownership from the pre-death damage log" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id, _killer -> :ok end)

    stub(Aesir.ZoneServer.Unit.Mob.KillExp, :distribute_typed, fn _damage_log,
                                                                  _base,
                                                                  _job,
                                                                  _level,
                                                                  _map,
                                                                  _race ->
      :ok
    end)

    for char_id <- [42, 100, 200] do
      UnitRegistry.register_unit(
        :player,
        char_id,
        PlayerState,
        struct(PlayerState,
          character_id: char_id,
          map_name: "prontera",
          action_state: :idle,
          stats: %{current_state: %{hp: 100}}
        ),
        self()
      )
    end

    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")

    state =
      build_mob_state(hp: 1, max_hp: 1, drops: [])
      |> MobState.add_aggro(100, 100)
      |> MobState.add_aggro(200, 200)
      |> MobState.add_typed_aggro({:player, 100}, 100, 100)
      |> MobState.add_typed_aggro({:player, 200}, 200, 200)

    pre_death_state =
      state
      |> MobState.add_aggro(42, 100)
      |> MobState.add_typed_aggro({:player, 42}, 42, 100)

    {:noreply, _dead_state} =
      MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, state)

    assert_receive {:loot, {:mob_killed, %{ownership: ownership, boss?: boss?}}}
    assert ownership == LootOwnership.determine_typed(pre_death_state)
    refute boss?
  end

  test "no_exp and no_drops suppress EXP distribution and drop generation" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id, _killer -> :ok end)
    reject(&Aesir.ZoneServer.Unit.Mob.KillExp.distribute_typed/6)

    :ok = PubSub.subscribe(Aesir.PubSub, "player:42")

    state =
      build_mob_state(hp: 1, max_hp: 1000, drops: [%MobDrop{item: "Red_Potion", rate: 10_000}])
      |> Map.put(:no_exp, true)
      |> Map.put(:no_drops, true)

    {:noreply, _state} = MobSession.handle_cast({:combat, {:apply_damage, 100, 42}}, state)

    refute_receive {:loot, {:mob_killed, _payload}}
  end

  test "a mob death with no killer broadcasts nothing" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id, _killer -> :ok end)

    :ok = PubSub.subscribe(Aesir.PubSub, "player:0")

    state =
      build_mob_state(hp: 1, max_hp: 1000, drops: [%MobDrop{item: "Red_Potion", rate: 10_000}])

    {:noreply, _state} = MobSession.handle_cast({:combat, {:apply_damage, 100, nil}}, state)

    refute_receive {:loot, {:mob_killed, _payload}}
  end

  test "non-death termination publishes exactly one normalized event" do
    :ok = Lifecycle.subscribe()
    stub(SpatialIndex, :remove_unit, fn :mob, 1 -> :ok end)
    stub(Broadcast, :publish_mob_despawn, fn "prontera", 1 -> :ok end)

    assert :ok = MobSession.terminate(:shutdown, build_mob_state(hp: 1, max_hp: 1, drops: []))

    assert_receive {:unit_lifecycle,
                    %Event{
                      unit_type: :mob,
                      unit_id: 1,
                      reason: :termination,
                      old_map: "prontera",
                      new_map: nil
                    } = event}

    refute_receive {:unit_lifecycle, ^event}
  end

  defp build_mob_state(opts) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      base_exp: 100,
      job_exp: 50,
      drops: opts[:drops],
      hp: opts[:max_hp],
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
    %{state | hp: opts[:hp], max_hp: opts[:max_hp]}
  end
end
