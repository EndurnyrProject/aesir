defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearstabTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearstab
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000
  @spear 1400
  @sword 1101
  @right_hand 2
  @map_name "prontera"

  defp build_caster(nameid \\ @spear, x \\ 150, y \\ 150) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 400, flee: 1, perfect_dodge: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment:
        Stats.equipment_from_inventory([
          %InventoryItem{nameid: nameid, amount: 1, equip: @right_hand, identify: 1}
        ])
    }

    %PlayerState{
      character_id: 1000,
      account_id: 1000,
      x: x,
      y: y,
      map_name: @map_name,
      stats: stats
    }
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:kn_spearstab)
    definition
  end

  test "Catalog.active_module_for/1 resolves kn_spearstab" do
    assert {:ok, KnSpearstab} = Catalog.active_module_for(:kn_spearstab)
  end

  test "definition carries the flat SP cost, weapon range, and level cap" do
    d = definition()

    assert d.id == 58
    assert d.display_name == "Spear Stab"
    assert d.max_level == 10
    assert d.range == -1
    assert d.sp_cost == List.duplicate(9, 10)
  end

  describe "validate/4" do
    test "accepts a one-handed or two-handed spear" do
      assert :ok = KnSpearstab.validate(build_caster(1400), {:unit, @target_id}, 5, definition())
    end

    test "rejects a player wielding any other weapon" do
      assert {:error, :requires_spear} =
               KnSpearstab.validate(build_caster(@sword), {:unit, @target_id}, 5, definition())
    end

    test "bypasses the gate for a mob caster" do
      mob = %{instance_id: 3000}
      assert :ok = KnSpearstab.validate(mob, {:unit, @target_id}, 5, definition())
    end
  end

  describe "cast/4" do
    test "deals (100 + 20 * level)% weapon damage without a crit roll" do
      caster = build_caster()

      expect(Combat, :execute_line_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_id] == definition().id
        assert opts[:skill_level] == 4
        assert opts[:skill_ratio] == 100 + 20 * 4
        assert opts[:skip_crit] == true
        [@target_id]
      end)

      assert {:ok, ^caster} = KnSpearstab.cast(caster, {:unit, @target_id}, 4, definition())
    end

    test "the ratio scales with every level" do
      caster = build_caster()

      for level <- 1..10 do
        expect(Combat, :execute_line_attack, fn ^caster, @target_id, opts ->
          assert opts[:skill_ratio] == 100 + 20 * level
          []
        end)

        assert {:ok, ^caster} = KnSpearstab.cast(caster, {:unit, @target_id}, level, definition())
      end
    end
  end

  describe "cast/4 against real targets" do
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

    test "hits both the target and an in-line mob, applies no knockback, and leaves positions untouched" do
      caster = build_caster()
      mob_pid = self()

      # Diagonal line (150, 150) -> (152, 152): the on-line mob sits at (151, 151),
      # the off-line mob at (151, 150) is untouched.
      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:mob, @target_id}, {:mob, 2001}, {:mob, 2002}]
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :player, _id -> {:error, :not_found}
        :mob, @target_id -> {:ok, {152, 152, @map_name}}
        :mob, 2001 -> {:ok, {151, 151, @map_name}}
        :mob, 2002 -> {:ok, {151, 150, @map_name}}
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:ok, {MobState, build_mob_state(@target_id, 152, 152), mob_pid}}
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 151, 151), mob_pid}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), mob_pid}}
      end)

      stub(DamageCalculator, :calculate_damage, fn _a, _t, _o -> {:ok, %{damage: 50}} end)
      stub(PacketFactory, :build_skill_damage_packet, fn _a, _t, _id, _lvl, _res -> :packet end)
      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, :packet -> :ok end)

      test_pid = self()

      stub(MobSession, :apply_damage, fn _pid, 50, 1000 ->
        send(test_pid, :apply_damage)
        :ok
      end)

      reject(&Combat.knockback/5)

      assert {:ok, ^caster} = KnSpearstab.cast(caster, {:unit, @target_id}, 5, definition())

      assert_received :apply_damage
      assert_received :apply_damage
      refute_received :apply_damage
    end
  end
end
