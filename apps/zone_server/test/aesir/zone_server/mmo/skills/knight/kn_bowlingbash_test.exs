defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbashTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbash
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup :verify_on_exit!

  @target_id 5_000
  @two_handed_sword 1_116
  # This mob is never registered in UnitRegistry, so any status row another
  # async test leaves behind under the same {:mob, id} key makes
  # `MobState.to_combatant/1` build a context for it and raise. Keep the
  # instance id out of the low range those tests reach for.
  @mob_caster_id 620_062

  describe "catalog registration" do
    test "Catalog.by_id(62) resolves to :kn_bowlingbash" do
      assert {:ok, definition} = Catalog.by_id(62)
      assert definition.name == :kn_bowlingbash
    end

    test "Catalog.by_name(:kn_bowlingbash) resolves" do
      assert {:ok, definition} = Catalog.by_name(:kn_bowlingbash)
      assert definition.id == 62
    end

    test "Catalog.active_module_for/1 resolves kn_bowlingbash" do
      assert {:ok, KnBowlingbash} = Catalog.active_module_for(:kn_bowlingbash)
    end

    test "definition carries the Renewal splash/target/sp values" do
      definition = definition()
      assert definition.display_name == "Bowling Bash"
      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.splash_radius == 2
      assert definition.sp_cost == [13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
    end
  end

  describe "skill_ratio/1" do
    test "is 100 + 40 percent per level" do
      assert KnBowlingbash.skill_ratio(1) == 140
      assert KnBowlingbash.skill_ratio(5) == 300
      assert KnBowlingbash.skill_ratio(10) == 500
    end
  end

  describe "knockback_distance/1" do
    test "scales 1 cell per 2 levels, from 1 at level 1 to 5 at level 10" do
      assert KnBowlingbash.knockback_distance(1) == 1
      assert KnBowlingbash.knockback_distance(2) == 1
      assert KnBowlingbash.knockback_distance(3) == 2
      assert KnBowlingbash.knockback_distance(4) == 2
      assert KnBowlingbash.knockback_distance(5) == 3
      assert KnBowlingbash.knockback_distance(6) == 3
      assert KnBowlingbash.knockback_distance(7) == 4
      assert KnBowlingbash.knockback_distance(8) == 4
      assert KnBowlingbash.knockback_distance(9) == 5
      assert KnBowlingbash.knockback_distance(10) == 5
    end
  end

  describe "hit_count/2" do
    test "is 2 with a one-handed weapon regardless of enemy count" do
      caster = build_player(fist())

      assert KnBowlingbash.hit_count(caster, 1) == 2
      assert KnBowlingbash.hit_count(caster, 2) == 2
      assert KnBowlingbash.hit_count(caster, 4) == 2
      assert KnBowlingbash.hit_count(caster, 10) == 2
    end

    test "is 2 with a two-handed sword and only the primary target in splash" do
      caster = build_player(two_handed_sword())

      assert KnBowlingbash.hit_count(caster, 1) == 2
    end

    test "is 3 with a two-handed sword and 2 or 3 enemies in splash" do
      caster = build_player(two_handed_sword())

      assert KnBowlingbash.hit_count(caster, 2) == 3
      assert KnBowlingbash.hit_count(caster, 3) == 3
    end

    test "is 4 with a two-handed sword and 4 or more enemies in splash" do
      caster = build_player(two_handed_sword())

      assert KnBowlingbash.hit_count(caster, 4) == 4
      assert KnBowlingbash.hit_count(caster, 7) == 4
    end

    test "is 2 for a mob caster regardless of enemy count" do
      caster = build_mob(@mob_caster_id, 10, 10)

      assert KnBowlingbash.hit_count(caster, 4) == 2
    end
  end

  describe "cast/4" do
    test "splashes the target cell, knocks each hit back, and uses the base hit count" do
      caster = build_player(fist(), x: 10, y: 20)
      level = 3

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)
      stub(Combat, :splash_targets, fn "prontera", {15, 25}, 2, _combatant -> [{:mob, 1}] end)

      expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
        assert opts[:skill_id] == 62
        assert opts[:skill_level] == level
        assert opts[:skill_ratio] == 220
        assert opts[:hit_count] == 2
        assert opts[:skip_crit] == true
        [101, 102]
      end)

      expect(Combat, :knockback, 2, fn :mob, target_id, 10, 20, 2 ->
        assert target_id in [101, 102]
        {:ok, {0, 0}}
      end)

      assert {:ok, ^caster} = KnBowlingbash.cast(caster, {:unit, @target_id}, level, definition())
    end

    test "raises the hit count to 3 for a two-handed sword with 2+ enemies in splash" do
      caster = build_player(two_handed_sword(), x: 10, y: 20)
      level = 1

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

      stub(Combat, :splash_targets, fn "prontera", {15, 25}, 2, _combatant ->
        [{:mob, 1}, {:mob, 2}]
      end)

      expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
        assert opts[:hit_count] == 3
        []
      end)

      stub(Combat, :knockback, fn _, _, _, _, _ -> {:ok, {0, 0}} end)

      assert {:ok, ^caster} = KnBowlingbash.cast(caster, {:unit, @target_id}, level, definition())
    end

    test "raises the hit count to 4 for a two-handed sword with 4+ enemies in splash" do
      caster = build_player(two_handed_sword(), x: 10, y: 20)
      level = 1

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

      stub(Combat, :splash_targets, fn "prontera", {15, 25}, 2, _combatant ->
        [{:mob, 1}, {:mob, 2}, {:mob, 3}, {:mob, 4}]
      end)

      expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
        assert opts[:hit_count] == 4
        []
      end)

      stub(Combat, :knockback, fn _, _, _, _, _ -> {:ok, {0, 0}} end)

      assert {:ok, ^caster} = KnBowlingbash.cast(caster, {:unit, @target_id}, level, definition())
    end

    test "knocks back each hit target the level-scaled distance" do
      caster = build_player(fist(), x: 10, y: 20)
      level = 9

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)
      stub(Combat, :splash_targets, fn "prontera", {15, 25}, 2, _combatant -> [{:mob, 1}] end)
      stub(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, _opts -> [101] end)

      expect(Combat, :knockback, fn :mob, 101, 10, 20, 5 -> {:ok, {0, 0}} end)

      assert {:ok, ^caster} = KnBowlingbash.cast(caster, {:unit, @target_id}, level, definition())
    end

    test "knocks the primary target back from the caster's cell, not the target's own cell" do
      caster = build_player(fist(), x: 10, y: 20)
      level = 1
      primary_target_id = 999

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

      stub(Combat, :splash_targets, fn "prontera", {15, 25}, 2, _combatant ->
        [{:mob, primary_target_id}]
      end)

      stub(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, _opts ->
        [primary_target_id]
      end)

      expect(Combat, :knockback, fn :mob, ^primary_target_id, from_x, from_y, _distance ->
        # The primary target stands exactly on the splash center {15, 25}. If the
        # knockback origin were that same cell, sign(x - from) would be {0, 0}
        # and Knockback's no-move clause would swallow the hit every cast. The
        # origin must be the caster's cell so the direction is never degenerate.
        assert {from_x, from_y} == {caster.x, caster.y}
        refute {from_x, from_y} == {15, 25}
        {:ok, {0, 0}}
      end)

      assert {:ok, ^caster} = KnBowlingbash.cast(caster, {:unit, @target_id}, level, definition())
    end

    test "propagates a target resolution error and deals no damage" do
      caster = build_player(fist())

      reject(&Combat.execute_splash_attack/4)
      reject(&Combat.knockback/5)

      stub(Combat, :resolve_combatant, fn @target_id -> {:error, :target_not_found} end)

      assert {:error, :target_not_found} =
               KnBowlingbash.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "casts from a mob caster with the base hit count" do
      caster = build_mob(@mob_caster_id, 10, 20)
      level = 2

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)
      stub(Combat, :splash_targets, fn "prontera", {15, 25}, 2, _combatant -> [{:mob, 1}] end)

      expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
        assert opts[:hit_count] == 2
        []
      end)

      stub(Combat, :knockback, fn _, _, _, _, _ -> {:ok, {0, 0}} end)

      assert {:ok, ^caster} = KnBowlingbash.cast(caster, {:unit, @target_id}, level, definition())
    end
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:kn_bowlingbash)
    definition
  end

  defp fist, do: %Equipment{}
  defp two_handed_sword, do: %Equipment{right_hand: @two_handed_sword}

  defp build_player(equipment, opts \\ []) do
    x = Keyword.get(opts, :x, 10)
    y = Keyword.get(opts, :y, 20)

    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
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
