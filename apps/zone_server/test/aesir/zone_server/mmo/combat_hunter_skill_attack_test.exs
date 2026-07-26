defmodule Aesir.ZoneServer.Mmo.CombatHunterSkillAttackTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
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
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(DamageApplication)
    :ok
  end

  @caster_id 1000
  @target_id 2001
  @map_name "prontera"

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 99, luk: 1},
      combat_stats: %{atk: 100, def: 1, hit: 200, flee: 1, perfect_dodge: 1, matk: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      current_state: %CurrentState{hp: 100, sp: 50},
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

  defp build_target(hp, agi \\ 10) do
    definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "TestMob",
      level: 1,
      hp: hp,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk: 10,
      matk: 0,
      def: 5,
      mdef: 3,
      stats: %{str: 10, agi: agi, vit: 10, int: 5, dex: 10, luk: 5},
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

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: @target_id,
      mob_id: 1002,
      mob_data: definition,
      spawn_ref: spawn,
      x: 150,
      y: 150,
      map_name: @map_name,
      hp: hp,
      max_hp: hp,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  defp stub_target(target) do
    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {MobState, target, self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, @map_name}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
  end

  test "ignore_flee connects a weapon splash without changing its public hit list" do
    caster = build_caster()
    target = build_target(100, 10_000)
    stub_target(target)

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
      [{:mob, @target_id}]
    end)

    expect(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(MobSession, :apply_damage, fn _pid, 40, @caster_id -> :ok end)

    assert [@target_id] =
             Combat.execute_splash_attack(caster, {150, 150}, 1,
               skill_id: 121,
               skill_level: 5,
               skill_ratio: 100,
               ignore_flee: true
             )
  end

  test "weapon splash still rolls flee by default" do
    caster = build_caster()
    target = build_target(100, 10_000)
    stub_target(target)

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
      [{:mob, @target_id}]
    end)

    reject(&DamageCalculator.calculate_damage/3)
    reject(&MobSession.apply_damage/3)

    assert [] =
             Combat.execute_splash_attack(caster, {150, 150}, 1,
               skill_id: 121,
               skill_level: 5,
               skill_ratio: 100
             )
  end

  test "reported hits include prepared damage and survival from the target snapshot" do
    caster = build_caster()
    target = build_target(40)
    stub_target(target)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(MobSession, :apply_damage, fn _pid, 40, @caster_id -> :ok end)

    assert {:ok, %{hit?: true, damage: 40, target_survives?: false}} =
             Combat.execute_skill_attack(caster, @target_id,
               skill_id: 1009,
               skill_level: 1,
               skill_ratio: 500,
               report_hit: true
             )
  end

  test "reported damage uses the post-absorption prepared amount" do
    caster = build_caster()
    target = build_target(40)
    stub_target(target)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(DamageApplication, :prepare_unit_damage, fn :mob, @target_id, 40, hit_info, @caster_id ->
      {10, hit_info}
    end)

    expect(MobSession, :apply_damage, fn _pid, 10, @caster_id -> :ok end)

    assert {:ok, %{hit?: true, damage: 10, target_survives?: true}} =
             Combat.execute_skill_attack(caster, @target_id,
               skill_id: 1009,
               skill_level: 1,
               skill_ratio: 500,
               report_hit: true
             )
  end
end
