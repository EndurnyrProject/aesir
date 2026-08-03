defmodule Aesir.ZoneServer.Unit.Mob.MobSessionSleepTest do
  @moduledoc """
  Verifies the dormant-mob lifecycle: spawning asleep on an empty map, the
  {:ai, :sleep}/{:ai, :wake} casts, and that a sleeping mob neither processes nor reschedules
  AI ticks.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  setup do
    stub(SpatialIndex, :add_unit, fn :mob, _id, _x, _y, _map -> :ok end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    stub(StatusDisplay, :spawn_state, fn :mob, _id ->
      %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0}
    end)

    :ok
  end

  describe "init/1" do
    test "spawning awake schedules the first AI tick" do
      assert {:ok, state} = MobSession.init(%{state: build_mob_state(1), awake: true})

      assert state.ai_awake
      assert is_reference(state.ai_timer_ref)
    end

    test "spawning on a dormant map schedules nothing and hibernates" do
      assert {:ok, state, :hibernate} =
               MobSession.init(%{state: build_mob_state(2), awake: false})

      refute state.ai_awake
      assert state.ai_timer_ref == nil
    end

    test "awake defaults to true when the option is absent" do
      assert {:ok, state} = MobSession.init(%{state: build_mob_state(3)})

      assert state.ai_awake
    end
  end

  describe "sleep/wake casts" do
    test "{:ai, :sleep} cancels the AI timer and sheds movement and target" do
      {:ok, state} = MobSession.init(%{state: build_mob_state(4), awake: true})

      state = %{
        state
        | movement_state: :moving,
          walk_path: [{51, 50}],
          target_ref: {:player, 99},
          ai_state: :chase
      }

      assert {:noreply, slept, :hibernate} = MobSession.handle_cast({:ai, :sleep}, state)

      refute slept.ai_awake
      assert slept.ai_timer_ref == nil
      assert slept.movement_state == :standing
      assert slept.walk_path == []
      assert slept.target_ref == nil
      assert slept.ai_state == :idle
    end

    test "{:ai, :sleep} on an already-sleeping mob is a no-op" do
      {:ok, state, :hibernate} = MobSession.init(%{state: build_mob_state(5), awake: false})

      assert {:noreply, ^state} = MobSession.handle_cast({:ai, :sleep}, state)
    end

    test "{:ai, :wake} reschedules the AI tick" do
      {:ok, state, :hibernate} = MobSession.init(%{state: build_mob_state(6), awake: false})

      assert {:noreply, woke} = MobSession.handle_cast({:ai, :wake}, state)

      assert woke.ai_awake
      assert is_reference(woke.ai_timer_ref)
    end

    test "{:ai, :wake} on an already-awake mob does not stack a second timer" do
      {:ok, state} = MobSession.init(%{state: build_mob_state(7), awake: true})

      assert {:noreply, ^state} = MobSession.handle_cast({:ai, :wake}, state)
    end
  end

  describe "{:ai, :tick} while asleep" do
    test "a tick that raced a {:ai, :sleep} is dropped without rescheduling" do
      {:ok, state, :hibernate} = MobSession.init(%{state: build_mob_state(8), awake: false})

      assert {:noreply, ^state} = MobSession.handle_info({:ai, :tick}, state)
      assert state.ai_timer_ref == nil
    end
  end

  defp build_mob_state(instance_id) do
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
      spawn_ref: %MobSpawn{
        mob: 1002,
        amount: 1,
        respawn_time: 0,
        spawn_area: %MobSpawn.SpawnArea{x: 50, y: 50, xs: 0, ys: 0}
      },
      map_name: "prontera",
      x: 50,
      y: 50,
      hp: 60,
      max_hp: 60,
      sp: 0,
      max_sp: 0,
      spawned_at: System.system_time(:second)
    }
  end
end
