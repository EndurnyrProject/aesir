defmodule Aesir.ZoneServer.Mmo.CombatMagicDamageTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
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
  @skill_id 28
  @skill_level 5

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 100},
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

  defp build_mob_state(unit_id, x, y, element) do
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
      element: element,
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

  defp stub_mob_target(x, y, element) do
    stub(UnitRegistry, :get_unit, fn
      :mob, @target_id -> {:ok, {MobState, build_mob_state(@target_id, x, y, element), self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, @target_id -> {:ok, {x, y, @map_name}}
    end)
  end

  describe "execute_magic_damage/4" do
    test "applies the element modifier and broadcasts a SkillDamage packet (holy vs undead)" do
      caster = build_caster()
      test_pid = self()
      stub_mob_target(150, 150, {:undead, 1})

      stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :holy
               )

      assert_received {:packet,
                       %SkillDamage{damage: 125, div: 1, skill_id: @skill_id, level: @skill_level}}

      assert_received {:damage, 125}
    end

    test "passes the amount through unchanged for matching element (neutral vs neutral)" do
      caster = build_caster()
      test_pid = self()
      stub_mob_target(150, 150, {:neutral, 1})

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 200,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :neutral
               )

      assert_received {:damage, 200}
    end

    test "defaults to :neutral element when :element opt is absent" do
      caster = build_caster()
      test_pid = self()
      stub_mob_target(150, 150, {:neutral, 1})

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, _caster ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 50,
                 skill_id: @skill_id,
                 skill_level: @skill_level
               )

      assert_received {:damage, 50}
    end

    test "returns {:error, :target_out_of_range} for a target beyond caster attack range" do
      caster = build_caster()
      stub_mob_target(170, 170, {:neutral, 1})

      assert {:error, :target_out_of_range} =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :holy
               )
    end

    test "returns {:error, :pvp_not_implemented} for a player target" do
      caster = build_caster()
      target_player = spawn(fn -> Process.sleep(:infinity) end)

      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)

      stub(PlayerSession, :get_current_stats, fn ^target_player -> build_caster().stats end)

      stub(PlayerSession, :get_state, fn ^target_player ->
        %{game_state: %{build_caster() | character_id: @target_id, x: 150, y: 150}}
      end)

      assert {:error, :pvp_not_implemented} =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :holy
               )
    end
  end
end
