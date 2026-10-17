defmodule Aesir.ZoneServer.Unit.Mob.MobWalkRequestTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "mob_walk_request_map"
  @mob_id 8

  setup :setup_ets_tables

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    SpatialIndex.add_unit(:mob, @mob_id, 30, 30, @map)
    UnitRegistry.register_unit(:mob, @mob_id, MobState, mob(), self())
    :ok
  end

  describe "a walk request" do
    test "stops the mob's attack" do
      attacking = %{mob() | attack_target: {:unit, :player, 1}, attack_timer_at: 123}

      {:noreply, walking} = MovementHandler.handle_move_to(attacking, 33, 30)

      assert walking.attack_target == nil
      assert walking.attack_timer_at == nil
      assert walking.movement_state == :moving
    end

    test "an escape walk stops it too" do
      attacking = %{mob() | attack_target: {:unit, :player, 1}, attack_timer_at: 123}

      escaped = MovementHandler.escape(attacking, {27, 30}, 8)

      assert escaped.attack_target == nil
      assert escaped.movement_state == :moving
    end

    test "refuses a walk longer than seventeen steps" do
      {:noreply, unchanged} = MovementHandler.handle_move_to(mob(), 48, 30)

      assert unchanged.movement_state == :standing
    end

    test "a chase walk is not refused for its length" do
      {:noreply, walking} = MovementHandler.handle_move_to(mob(), 48, 30, chase: true)

      assert walking.movement_state == :moving
      assert length(walking.walk_path) == 18
    end

    test "with no path leaves the attack running" do
      attacking = %{mob() | attack_target: {:unit, :player, 1}, attack_timer_at: 123}

      {:noreply, unchanged} = MovementHandler.handle_move_to(attacking, 300, 300)

      assert unchanged.attack_target == {:unit, :player, 1}
    end
  end

  describe "a confused mob" do
    setup do
      :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_confusion, duration: 60_000)
      :ok
    end

    test "walks to a random cell as far as the requested one" do
      # (30, 35) is straight north: no diagonal candidate keeps x at 30.
      {:noreply, walking} = MovementHandler.handle_move_to(mob(), 30, 35)

      assert walking.movement_state == :moving
      assert List.last(walking.walk_path) in candidates({30, 30}, 25)
    end

    test "redirects a walk in progress to a random cell" do
      {:noreply, walking} = MovementHandler.handle_move_to(mob(), 31, 30)
      {:noreply, redirected} = MovementHandler.handle_move_to(walking, 30, 35)

      assert redirected.walk_target in candidates({30, 30}, 25)
    end
  end

  defp candidates({x, y}, dist2) do
    dist = trunc(:math.sqrt(dist2))

    for {dx, dy} <- [{-1, 1}, {-1, -1}, {1, -1}, {1, 1}], s <- 1..dist do
      {x + s * dx, y + trunc(:math.sqrt(dist2 - s * s)) * dy}
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
