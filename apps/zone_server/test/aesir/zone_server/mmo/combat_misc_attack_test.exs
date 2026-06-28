defmodule Aesir.ZoneServer.Mmo.CombatMiscAttackTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
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
  @target_id 2001
  @map_name "prontera"
  @center {150, 150}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 1},
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

  defp stub_single_target_mob(x \\ 150, y \\ 150) do
    stub(UnitRegistry, :get_unit, fn
      :mob, @target_id -> {:ok, {MobState, build_mob_state(@target_id, x, y), self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, @target_id -> {:ok, {x, y, @map_name}}
    end)
  end

  describe "execute_misc_attack/3" do
    test "broadcasts a SkillDamage packet and applies the misc damage" do
      caster = build_caster()
      test_pid = self()
      stub_single_target_mob()

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _a, _t, opts ->
        assert opts[:base_damage] == 250
        assert opts[:element] == :fire
        {:ok, %{damage: 80, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250,
                 element: :fire
               )

      assert_received {:packet, %SkillDamage{damage: 80, skill_id: 122, level: 5}}
      assert_received {:damage, 80}
    end
  end

  describe "execute_misc_splash/4" do
    test "hits every target in the splash for misc damage" do
      caster = build_caster()
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      hits =
        Combat.execute_misc_splash(caster, @center, 1,
          skill_id: 122,
          skill_level: 5,
          base_damage: 200,
          element: :neutral
        )

      assert Enum.sort(hits) == [2001, 2002]
      assert_received {:damage, 40}
      assert_received {:damage, 40}
    end
  end
end
