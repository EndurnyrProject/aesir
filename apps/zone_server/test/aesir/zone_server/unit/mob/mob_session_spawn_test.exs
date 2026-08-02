defmodule Aesir.ZoneServer.Unit.Mob.MobSessionSpawnTest do
  @moduledoc """
  Verifies the mob spawn broadcast carries the sprite-state aggregate sourced
  from `StatusDisplay.spawn_state/2`.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(KillExp)
  end

  test "the mob spawn broadcast carries its sprite-state aggregate" do
    test_pid = self()

    stub(SpatialIndex, :add_unit, fn :mob, _id, _x, _y, _map -> :ok end)

    stub(StatusDisplay, :spawn_state, fn :mob, 7 ->
      %{body_state: 1, health_state: 4, effect_state: 8, virtue: 2}
    end)

    expect(Broadcast, :to_in_range, fn _map, _x, _y, _range, %UnitSpawn{} = packet ->
      send(test_pid, {:spawn_broadcast, packet})
      :ok
    end)

    {:ok, _state} = MobSession.init(%{state: build_mob_state(7)})

    assert_received {:spawn_broadcast,
                     %UnitSpawn{
                       gid: 7,
                       body_state: 1,
                       health_state: 4,
                       effect_state: 8,
                       virtue: 2
                     }}
  end

  test "a lifetime schedules clean despawn and unregisters without death handling" do
    state = build_mob_state(9)

    stub(SpatialIndex, :add_unit, fn :mob, 9, 51, 50, "prontera" -> :ok end)
    stub(SpatialIndex, :remove_unit, fn :mob, 9 -> :ok end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Broadcast, :publish_mob_despawn, fn "prontera", 9 -> :ok end)
    reject(&Coordinator.mob_died/3)
    reject(&KillExp.distribute/6)

    UnitRegistry.register_unit(:mob, 9, MobState, state, self())

    {:ok, initialized, :hibernate} =
      MobSession.init(%{state: state, awake: false, lifetime_ms: 50})

    assert_receive :despawn, 100
    assert {:stop, :normal, ^initialized} = MobSession.handle_info(:despawn, initialized)
    assert {:error, :not_found} = UnitRegistry.get_unit(:mob, 9)
    assert :ok = MobSession.terminate(:normal, initialized)
  end

  test "a dead mob's spawn carries only the opt2 aggregate, never a dead bit in health_state" do
    test_pid = self()

    stub(SpatialIndex, :add_unit, fn :mob, _id, _x, _y, _map -> :ok end)

    stub(StatusDisplay, :spawn_state, fn :mob, 8 ->
      %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, %UnitSpawn{} = packet ->
      send(test_pid, {:spawn_broadcast, packet})
      :ok
    end)

    {:ok, _state} = MobSession.init(%{state: build_mob_state(8, true)})

    assert_received {:spawn_broadcast, %UnitSpawn{gid: 8, health_state: 0}}
  end

  defp build_mob_state(instance_id, is_dead \\ false) do
    %MobState{
      instance_id: instance_id,
      mob_id: 1002,
      mob_data: %MobDefinition{
        id: 1002,
        aegis_name: "PORING",
        name: "Poring",
        level: 3,
        hp: 60,
        sp: 0,
        atk: 7,
        matk: 0,
        def: 0,
        mdef: 5,
        stats: %{str: 1, agi: 1, vit: 1, int: 0, dex: 6, luk: 30},
        attack_range: 1,
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 672,
        client_attack_motion: 500,
        damage_motion: 480,
        element: {:water, 1},
        race: :plant,
        size: :medium
      },
      spawn_ref: nil,
      map_name: "prontera",
      x: 51,
      y: 50,
      dir: 0,
      hp: 50,
      max_hp: 60,
      sp: 0,
      max_sp: 0,
      spawned_at: System.system_time(:second),
      walk_speed: 200,
      is_dead: is_dead
    }
  end
end
