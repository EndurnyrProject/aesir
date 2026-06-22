defmodule Aesir.ZoneServer.Mmo.CombatSplashTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: @caster_id,
      account_id: @caster_id,
      x: 150,
      y: 150,
      map_name: @map_name,
      stats: stats
    }
  end

  defp build_mob_state(unit_id, x, y) do
    mob_definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "TestMob",
      level: 1,
      hp: 100,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk: 10,
      matk: 0,
      def: 5,
      mdef: 3,
      stats: %{str: 10, agi: 10, vit: 10, int: 5, dex: 10, luk: 5},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    mob_spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: unit_id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: mob_spawn,
      x: x,
      y: y,
      map_name: @map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  test "execute_splash_attack hits in-radius mobs, skips the caster, and returns hit ids" do
    caster = build_caster()
    mob_pid_a = self()
    mob_pid_b = self()

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
      [{:mob, 2001}, {:mob, 2002}, {:player, @caster_id}]
    end)

    stub(UnitRegistry, :get_unit, fn
      :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 151, 150), mob_pid_a}}
      :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 149, 150), mob_pid_b}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 2001 -> {:ok, {151, 150, @map_name}}
      :mob, 2002 -> {:ok, {149, 150, @map_name}}
    end)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(PacketFactory, :build_skill_damage_packet, fn _a, _t, _id, _lvl, _res -> :packet end)

    test_pid = self()

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, :packet ->
      send(test_pid, :broadcast)
      :ok
    end)

    stub(MobSession, :apply_damage, fn _pid, 50, @caster_id ->
      send(test_pid, :apply_damage)
      :ok
    end)

    hits =
      Combat.execute_splash_attack(caster, @center, 2,
        skill_id: 7,
        skill_level: 5,
        skill_ratio: 200,
        skip_crit: true
      )

    assert Enum.sort(hits) == [2001, 2002]
    assert_received :broadcast
    assert_received :apply_damage
    assert_received :broadcast
    assert_received :apply_damage
  end

  test "execute_splash_attack hits a mob at the square corner (Chebyshev radius)" do
    caster = build_caster()

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
      [{:mob, 2001}]
    end)

    stub(UnitRegistry, :get_unit, fn
      :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 152, 152), self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 2001 -> {:ok, {152, 152, @map_name}}
    end)

    stub(DamageCalculator, :calculate_damage, fn _a, _t, _o ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(PacketFactory, :build_skill_damage_packet, fn _a, _t, _id, _lvl, _res -> :packet end)
    stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, :packet -> :ok end)
    stub(MobSession, :apply_damage, fn _pid, 50, @caster_id -> :ok end)

    hits =
      Combat.execute_splash_attack(caster, @center, 2,
        skill_id: 7,
        skill_level: 5,
        skill_ratio: 200,
        skip_crit: true
      )

    assert hits == [2001]
  end

  test "execute_splash_attack skips a mob outside the square" do
    caster = build_caster()

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
      [{:mob, 2001}]
    end)

    stub(UnitRegistry, :get_unit, fn
      :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 153, 150), self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 2001 -> {:ok, {153, 150, @map_name}}
    end)

    hits =
      Combat.execute_splash_attack(caster, @center, 2,
        skill_id: 7,
        skill_level: 5,
        skill_ratio: 200,
        skip_crit: true
      )

    assert hits == []
  end

  test "execute_splash_attack skips a dead mob inside the radius" do
    caster = build_caster()
    dead_mob = %{build_mob_state(2001, 151, 150) | hp: 0}

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
      [{:mob, 2001}]
    end)

    stub(UnitRegistry, :get_unit, fn
      :mob, 2001 -> {:ok, {MobState, dead_mob, self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 2001 -> {:ok, {151, 150, @map_name}}
    end)

    hits =
      Combat.execute_splash_attack(caster, @center, 2,
        skill_id: 7,
        skill_level: 5,
        skill_ratio: 200,
        skip_crit: true
      )

    assert hits == []
  end
end
