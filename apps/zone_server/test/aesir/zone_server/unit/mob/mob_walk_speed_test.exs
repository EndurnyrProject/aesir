defmodule Aesir.ZoneServer.Unit.Mob.MobWalkSpeedTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "mob_walk_speed_map"
  @mob_id 7

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    SpatialIndex.add_unit(:mob, @mob_id, 30, 30, @map)
    UnitRegistry.register_unit(:mob, @mob_id, MobState, mob(), self())
    :ok
  end

  describe "a speed status on a monster" do
    test "slows its walk speed from its base and the next step uses it" do
      :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_decreaseagi, val1: 1, duration: 60_000)

      assert {:noreply, slowed} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_decreaseagi, :apply}},
                 mob()
               )

      assert slowed.base.speed == 200
      assert slowed.calculated.speed == 250

      {:noreply, walking} = MovementHandler.handle_move_to(slowed, 31, 30)
      assert {_due_at, 250, _ref} = walking.pending_step
    end

    test "a diagonal step takes 14/10 of the slowed speed" do
      :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_decreaseagi, val1: 1, duration: 60_000)

      assert {:noreply, slowed} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_decreaseagi, :apply}},
                 mob()
               )

      {:noreply, walking} = MovementHandler.handle_move_to(slowed, 31, 31)
      assert {_due_at, 350, _ref} = walking.pending_step
    end

    test "the strongest slow wins and its end restores the base speed" do
      :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_decreaseagi, val1: 1, duration: 60_000)
      :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_quagmire, val1: 1, duration: 60_000)

      assert {:noreply, slowed} =
               MobSession.handle_cast({:casting, {:status_changed, :sc_quagmire, :apply}}, mob())

      assert slowed.calculated.speed == 300

      StatusStorage.remove_status(:mob, @mob_id, :sc_decreaseagi)
      StatusStorage.remove_status(:mob, @mob_id, :sc_quagmire)

      assert {:noreply, restored} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_decreaseagi, :removed}},
                 mob()
               )

      assert restored.calculated.speed == 200
    end

    test "a dead monster keeps its speed" do
      :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_decreaseagi, val1: 1, duration: 60_000)
      dead = %{mob() | is_dead: true}

      assert {:noreply, ^dead} =
               MobSession.handle_cast(
                 {:casting, {:status_changed, :sc_decreaseagi, :apply}},
                 dead
               )
    end
  end

  defp mob do
    mob_data =
      struct!(MobDefinition, %{
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
        skill_range: 10,
        chase_range: 12,
        walk_speed: 200,
        attack_delay: 1200,
        attack_motion: 500,
        client_attack_motion: 400,
        damage_motion: 300,
        element: {:neutral, 1},
        race: :formless,
        size: :medium
      })

    spawn_ref =
      struct!(MobSpawn, %{
        mob: 1001,
        amount: 1,
        respawn_time: 5000,
        spawn_area: struct!(SpawnArea, %{x: 30, y: 30})
      })

    @mob_id
    |> MobState.new(mob_data, spawn_ref, @map, 30, 30)
    |> Map.put(:last_skillcheck, System.system_time(:millisecond))
  end
end
