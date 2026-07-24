defmodule Aesir.ZoneServer.Mmo.Combat.SplashTargetsTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
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

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 200, flee: 1, perfect_dodge: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      current_state: %CurrentState{hp: 100, sp: 50, ap: 0},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: @caster_id,
      account_id: @caster_id,
      x: 150,
      y: 150,
      map_name: @map_name,
      action_state: :idle,
      stats: stats
    }
  end

  defp build_mob(unit_id, x, y) do
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

  defp stub_ground_unit_footprint do
    caster = build_caster()
    mob = build_mob(2001, 151, 150)

    stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
      [{:mob, 2001}, {:player, @caster_id}]
    end)

    stub(UnitRegistry, :get_unit, fn
      :mob, 2001 -> {:ok, {MobState, mob, self()}}
      :player, @caster_id -> {:ok, {PlayerState, caster, self()}}
    end)

    stub(UnitRegistry, :get_player_pid, fn @caster_id -> {:ok, self()} end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, 2001 -> {:ok, {151, 150, @map_name}}
      :player, @caster_id -> {:ok, {150, 150, @map_name}}
    end)
  end

  test "without hits_caster the caster is excluded from its own ground unit's targets" do
    stub_ground_unit_footprint()

    assert Enum.sort(SplashTargets.select(@map_name, @center, 2, @caster_id)) == [{:mob, 2001}]
  end

  test "with hits_caster: true the caster is included in its own ground unit's targets" do
    stub_ground_unit_footprint()

    assert Enum.sort(SplashTargets.select(@map_name, @center, 2, @caster_id, true)) ==
             [{:mob, 2001}, {:player, @caster_id}]
  end
end
