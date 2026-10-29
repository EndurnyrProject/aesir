defmodule Aesir.ZoneServer.Unit.Mob.MobHitStopTest do
  use ExUnit.Case, async: true
  use Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Movement, :set_position, fn _type, _id, _state, _map -> :ok end)
    :ok
  end

  defp walking_mob(opts \\ []) do
    step = HitStop.schedule({:movement, :tick}, 10_000)

    %{
      MobState.set_path(mob(), [{101, 100}, {102, 100}])
      | pending_step: step,
        can_escape: Keyword.get(opts, :can_escape, false)
    }
  end

  defp hit(state, metadata),
    do: MobSession.handle_cast({:combat, {:apply_damage, 10, nil, metadata}}, state)

  test "a damaging battle hit stops a walking mob on its cell" do
    {:noreply, hit_mob} = hit(walking_mob(), %{walk_delay?: true})

    assert hit_mob.movement_state == :standing
    assert {hit_mob.x, hit_mob.y} == {100, 100}
    refute_receive {:timeout, _timer, {:movement, :tick}}
  end

  test "a coma hit carries its walk delay and stops the mob" do
    {:noreply, hit_mob} =
      MobSession.handle_cast(
        {:combat, {:apply_coma, nil, %{walk_delay?: true, coma?: true}}},
        walking_mob()
      )

    assert hit_mob.hp == 1
    assert hit_mob.movement_state == :standing
  end

  test "a hit that carries no walk delay leaves the walk alone" do
    {:noreply, hit_mob} = hit(walking_mob(), %{})

    assert hit_mob.movement_state == :moving
  end

  test "an escape walk cannot be stopped" do
    {:noreply, hit_mob} = hit(walking_mob(can_escape: true), %{walk_delay?: true})

    assert hit_mob.movement_state == :moving
  end

  test "an enduring mob keeps walking" do
    StatusStorage.apply_status(:mob, 1, :sc_endure, val1: 1)
    state = walking_mob()
    UnitRegistry.register_unit(:mob, 1, MobState, state, self())

    {:noreply, hit_mob} = hit(state, %{walk_delay?: true})

    assert hit_mob.movement_state == :moving
  end

  describe "a skill's walk delay" do
    test "stops a walking mob as a hit does and holds it until the delay ends" do
      before = HitStop.now()

      {:noreply, delayed} = walk_delay(walking_mob(), 300)

      assert delayed.movement_state == :standing
      assert {delayed.x, delayed.y} == {100, 100}
      assert delayed.walk_delay_until in (before + 300)..(HitStop.now() + 300)
    end

    test "a chasing mob resumes one millisecond after the delay" do
      chasing = %{walking_mob() | chase_target: {:player, 7}}

      {:noreply, delayed} = walk_delay(chasing, 100)

      at = delayed.walk_delay_until + 1
      assert delayed.chase_resume_at == at
      assert_receive {:ai, {:chase_resume, ^at}}, 500
    end

    test "a status-immune mob ignores it" do
      state = walking_mob()
      immune = %{state | calculated: %{state.calculated | mode: MobMode.mask([:status_immune])}}

      {:noreply, ignored} = walk_delay(immune, 300)

      assert ignored.movement_state == :moving
      assert ignored.walk_delay_until == 0
    end

    test "a delay already running past it is kept and stops nothing" do
      until = HitStop.now() + 5_000

      {:noreply, kept} = walk_delay(%{walking_mob() | walk_delay_until: until}, 300)

      assert kept.movement_state == :moving
      assert kept.walk_delay_until == until
    end
  end

  defp walk_delay(state, duration),
    do: MobSession.handle_cast({:movement, {:walk_delay, duration}}, state)

  defp mob do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
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

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
