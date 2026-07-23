defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBrandishspearTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnBrandishspear
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup :verify_on_exit!

  @target_id 5_000
  @one_handed_spear 1_402
  @riding_bit Option.id(:riding)

  describe "catalog registration" do
    test "Catalog.by_id(57) resolves to :kn_brandishspear" do
      assert {:ok, definition} = Catalog.by_id(57)
      assert definition.name == :kn_brandishspear
    end

    test "Catalog.by_name(:kn_brandishspear) resolves" do
      assert {:ok, definition} = Catalog.by_name(:kn_brandishspear)
      assert definition.id == 57
    end

    test "Catalog.active_module_for/1 resolves kn_brandishspear" do
      assert {:ok, KnBrandishspear} = Catalog.active_module_for(:kn_brandishspear)
    end

    test "definition carries the Renewal splash/target/sp values" do
      definition = definition()
      assert definition.display_name == "Brandish Spear"
      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.splash_radius == 2
      assert definition.sp_cost == List.duplicate(24, 10)
    end
  end

  describe "skill_ratio/2" do
    test "is 400 + 100 per level + 3 per point of STR" do
      assert KnBrandishspear.skill_ratio(1, 10) == 530
      assert KnBrandishspear.skill_ratio(5, 60) == 1_080
      assert KnBrandishspear.skill_ratio(10, 100) == 1_700
    end
  end

  describe "validate/4" do
    test "a mounted spear-wielding player passes" do
      caster = build_player(spear(), riding?: true)

      assert :ok = KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "an unmounted spear-wielding player is rejected" do
      caster = build_player(spear(), riding?: false)

      assert {:error, :requires_riding} =
               KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a mounted player without a spear is rejected" do
      caster = build_player(fist(), riding?: true)

      assert {:error, :requires_spear} =
               KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a mob caster bypasses both the spear and riding gates" do
      caster = build_mob(1, 10, 10)

      assert :ok = KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end
  end

  describe "cast/4" do
    test "splashes the target cell, uses STR in the ratio, and knocks each hit back" do
      caster = build_player(spear(), riding?: true, str: 60, x: 10, y: 20)
      level = 5

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

      expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
        assert opts[:skill_id] == 57
        assert opts[:skill_level] == level
        assert opts[:skill_ratio] == 1_080
        assert opts[:skip_crit] == true
        assert opts[:ranged] == true
        [101, 102]
      end)

      expect(Combat, :knockback, 2, fn :mob, target_id, 10, 20, 2 ->
        assert target_id in [101, 102]
        {:ok, {0, 0}}
      end)

      assert {:ok, ^caster} =
               KnBrandishspear.cast(caster, {:unit, @target_id}, level, definition())
    end

    test "knocks the primary target back from the caster's cell, not the target's own cell" do
      caster = build_player(spear(), riding?: true, x: 10, y: 20)
      primary_target_id = 999

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

      stub(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, _opts ->
        [primary_target_id]
      end)

      expect(Combat, :knockback, fn :mob, ^primary_target_id, from_x, from_y, 2 ->
        assert {from_x, from_y} == {caster.x, caster.y}
        refute {from_x, from_y} == {15, 25}
        {:ok, {0, 0}}
      end)

      assert {:ok, ^caster} = KnBrandishspear.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "propagates a target resolution error and deals no damage" do
      caster = build_player(spear(), riding?: true)

      reject(&Combat.execute_splash_attack/4)
      reject(&Combat.knockback/5)

      stub(Combat, :resolve_combatant, fn @target_id -> {:error, :target_not_found} end)

      assert {:error, :target_not_found} =
               KnBrandishspear.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "casts from a mob caster using its STR in the ratio" do
      caster = build_mob(1, 10, 20)
      level = 3

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

      expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
        assert opts[:skill_ratio] == KnBrandishspear.skill_ratio(level, 10)
        assert opts[:ranged] == true
        []
      end)

      stub(Combat, :knockback, fn _, _, _, _, _ -> {:ok, {0, 0}} end)

      assert {:ok, ^caster} =
               KnBrandishspear.cast(caster, {:unit, @target_id}, level, definition())
    end
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:kn_brandishspear)
    definition
  end

  defp fist, do: %Equipment{}
  defp spear, do: %Equipment{right_hand: @one_handed_spear}

  defp build_player(equipment, opts) do
    x = Keyword.get(opts, :x, 10)
    y = Keyword.get(opts, :y, 20)
    str = Keyword.get(opts, :str, 1)
    riding? = Keyword.get(opts, :riding?, false)
    option = if riding?, do: @riding_bit, else: 0

    stats = %Stats{
      base_stats: %BaseStats{str: str, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 70, job_level: 50, learned_skills: %{}},
      equipment: equipment
    }

    %PlayerState{
      character_id: 1_000,
      account_id: 1_000,
      x: x,
      y: y,
      map_name: "prontera",
      option: option,
      stats: stats
    }
  end

  defp build_mob(id, x, y) do
    mob_definition = %MobDefinition{
      id: 1_002,
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
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: id,
      mob_id: 1_002,
      mob_data: mob_definition,
      spawn_ref: spawn,
      x: x,
      y: y,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end
end
