defmodule Aesir.ZoneServer.Mmo.Homunculus.StatsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  test "Brain Surgery applies only to Lif forms without compounding" do
    state = state(6_001, %{8_003 => 5})
    effective = Stats.recompute(state)

    assert effective.max_sp == 210
    assert effective.combat_stats.sp_regen_rate == 15
    assert Stats.healing_touch_bonus_rate(effective) == 10
    assert Stats.recompute(effective) == effective

    evolved = Stats.recompute(%{state | class_id: 6_009})
    assert evolved.max_sp == 210

    wrong_species = Stats.recompute(%{state | class_id: 6_002})
    assert wrong_species.max_sp == 200
    assert wrong_species.combat_stats.sp_regen_rate == 0
    assert Stats.healing_touch_bonus_rate(wrong_species) == 0
  end

  test "Adamantium Skin applies raw-basis HP, hard DEF, and regen only to Amistr" do
    effective = Stats.recompute(state(6_002, %{8_007 => 4}))

    assert effective.max_hp == 1_080
    assert effective.combat_stats.def == 54
    assert effective.combat_stats.hp_regen_rate == 20
    assert effective.hp == 900

    unlearned = Stats.recompute(state(6_002, %{}))
    assert unlearned.max_hp == 1_000
    assert unlearned.combat_stats.def == 38
  end

  test "Instruction Change uses exact rank tables for original and evolved Vanilmirth" do
    for {rank, str_bonus, int_bonus} <- [
          {1, 1, 1},
          {2, 1, 2},
          {3, 3, 2},
          {4, 4, 4},
          {5, 4, 5}
        ] do
      original = Stats.recompute(state(6_004, %{8_015 => rank}))
      evolved = Stats.recompute(state(6_012, %{8_015 => rank}))

      assert original.str == 31 + str_bonus
      assert original.int == 25 + int_bonus
      assert evolved.str == original.str
      assert evolved.int == original.int
    end

    rank_five = Stats.recompute(state(6_004, %{8_015 => 5}))
    assert rank_five.combat_stats.mdef == 29
    assert rank_five.combat_stats.soft_mdef == 24
    assert rank_five.combat_stats.matk_min == 84
    assert rank_five.combat_stats.matk_max == 96

    wrong_species = Stats.recompute(state(6_003, %{8_015 => 5}))
    assert wrong_species.str == 31
    assert wrong_species.int == 25
  end

  test "Change stat deltas use incremental Renewal DEF and MDEF truncation boundaries" do
    effective = Stats.recompute(state(6_001, %{}), %{vit: 29, int: 19, def: 15, mdef: 7})

    assert effective.vit == 47
    assert effective.int == 44
    assert effective.combat_stats.def == 59
    assert effective.combat_stats.soft_def == 42
    assert effective.combat_stats.mdef == 37
    assert effective.combat_stats.soft_mdef == 45
  end

  test "Defence adds directly to hard DEF without changing soft DEF" do
    base = Stats.recompute(state(6_001, %{}))
    defended = Stats.recompute(state(6_001, %{}), %{def: 15})

    assert defended.combat_stats.def == base.combat_stats.def + 15
    assert defended.combat_stats.soft_def == base.combat_stats.soft_def
  end

  test "derives Renewal combat bounds and all Homunculus status reader channels" do
    modifiers = %{
      movement_speed: -80,
      vit: 30,
      int: 20,
      def: 15,
      atk_rate: 40,
      hom_aspd_rate: 120,
      flee: 50
    }

    effective = Stats.recompute(state(6_001, %{}), modifiers)

    assert %{str: 31, agi: 20, vit: 48, int: 45, dex: 40, luk: 10} = effective
    assert effective.combat_stats.atk == 111
    assert effective.combat_stats.atk_min == 14
    assert effective.combat_stats.atk_max == 27
    assert effective.combat_stats.def == 59
    assert effective.combat_stats.soft_def == 43
    assert effective.combat_stats.mdef == 31
    assert effective.combat_stats.soft_mdef == 47
    assert effective.combat_stats.hit == 230
    assert effective.combat_stats.flee == 110
    assert effective.combat_stats.critical == 44
    assert effective.combat_stats.matk_min == 102
    assert effective.combat_stats.matk_max == 116
    assert effective.attack_delay_ms == 542
    assert Stats.movement_delay_ms(200, modifiers) == 80
  end

  test "preserves absolute resources and clamps only when an effective maximum shrinks" do
    boosted = state(6_001, %{8_003 => 5}) |> Map.put(:sp, 205) |> Stats.recompute()
    assert boosted.sp == 205
    assert boosted.max_sp == 210

    shrunk = boosted |> Map.put(:learned_skills, %{}) |> Stats.recompute()
    assert shrunk.sp == 200
    assert shrunk.max_sp == 200
    assert shrunk.hp == 900
  end

  test "basic attacks become eligible exactly at the derived delay" do
    homunculus = %{Stats.recompute(state(6_001, %{})) | attack_delay_ms: 623}
    runtime = %Runtime{private_dirty: false, last_basic_attack_at_ms: 1_000}

    refute CombatHandler.basic_attack_ready?(runtime, homunculus, 1_622)
    assert CombatHandler.basic_attack_ready?(runtime, homunculus, 1_623)
  end

  defp state(class_id, learned_skills) do
    %HomunculusState{
      id: 1,
      owner_character_id: 10,
      class_id: class_id,
      name: "Homunculus",
      lifecycle: :active,
      level: 40,
      hp: 900,
      max_hp: 1_000,
      raw_max_hp: 1_000,
      sp: 190,
      max_sp: 200,
      raw_max_sp: 200,
      str: 31,
      raw_str: 31,
      agi: 20,
      raw_agi: 20,
      vit: 18,
      raw_vit: 18,
      int: 25,
      raw_int: 25,
      dex: 40,
      raw_dex: 40,
      luk: 10,
      raw_luk: 10,
      learned_skills: learned_skills,
      world_gid: 70_001,
      map_name: "stats_test",
      x: 10,
      y: 10,
      attack_delay_ms: 700,
      raw_attack_delay_ms: 700
    }
  end
end
