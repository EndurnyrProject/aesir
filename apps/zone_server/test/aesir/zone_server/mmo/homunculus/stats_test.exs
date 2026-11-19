defmodule Aesir.ZoneServer.Mmo.Homunculus.StatsTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blind
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  test "real snapshots separate displayed critical from chance and fix MATK at the mode maximum" do
    derived = Stats.recompute(state(6_001, %{}))
    combatant = HomunculusState.to_combatant(derived)
    expected_matk = %{renewal: 98, pre_renewal: 50}[GameMode.mode()]

    assert derived.combat_stats.critical == 4
    assert derived.combat_stats.critical_rate == 0
    assert derived.combat_stats.perfect_dodge == 0
    assert CriticalHits.calculate_critical_rate(combatant) == 0
    assert derived.combat_stats.matk == expected_matk
    assert derived.combat_stats.matk_min == expected_matk
    assert derived.combat_stats.matk_max == expected_matk
    assert Stats.recompute(derived) == derived
  end

  test "Blind reduces Homunculus HIT and FLEE by a quarter rather than 25 points" do
    state = state(6_001, %{})
    baseline = Stats.recompute(state)
    modifiers = Blind.modifiers(%StatusEntry{type: :sc_blind}, %{})
    blinded = Stats.recompute(state, modifiers)

    assert blinded.combat_stats.hit ==
             baseline.combat_stats.hit - div(baseline.combat_stats.hit * 25, 100)

    assert blinded.combat_stats.flee ==
             baseline.combat_stats.flee - div(baseline.combat_stats.flee * 25, 100)

    assert Stats.recompute(blinded, modifiers) == blinded
    assert Stats.recompute(blinded) == baseline
  end

  test "Divest percent cuts apply after the additive status bonuses" do
    cut =
      Stats.recompute(state(6_001, %{}), %{
        vit: 2,
        vit_cut_rate: 40,
        int_cut_rate: 40,
        def_cut_rate: 15
      })

    assert cut.vit == 12
    assert cut.int == 15
  end

  test "Divest Shield cuts status DEF before the VIT share is added" do
    full_strip =
      Stats.recompute(state(6_001, %{}), %{vit: 60, def: 30, vit_cut_rate: 40, def_cut_rate: 15})

    # VIT 78 cut to 47, VIT share 9 - 3 = 6. Renewal: 72 cut to 62; classic: 37 cut to 32.
    # Cutting after the VIT share would give 67 and 37.
    assert full_strip.combat_stats.def == %{renewal: 68, pre_renewal: 38}[GameMode.mode()]
  end

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
    assert effective.combat_stats.def == mode_value(58, 23)
    assert effective.combat_stats.hp_regen_rate == 20
    assert effective.hp == 900

    unlearned = Stats.recompute(state(6_002, %{}))
    assert unlearned.max_hp == 1_000
    assert unlearned.combat_stats.def == mode_value(42, 7)
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
    assert rank_five.combat_stats.mdef == mode_value(32, 9)
    assert rank_five.combat_stats.soft_mdef == mode_value(28, 39)
    assert rank_five.combat_stats.matk_min == mode_value(104, 66)
    assert rank_five.combat_stats.matk_max == mode_value(104, 66)

    wrong_species = Stats.recompute(state(6_003, %{8_015 => 5}))
    assert wrong_species.str == 31
    assert wrong_species.int == 25
  end

  test "Change stat deltas use each mode's incremental DEF and MDEF truncation boundaries" do
    effective = Stats.recompute(state(6_001, %{}), %{vit: 29, int: 19, def: 15, mdef: 7})

    assert effective.vit == 47
    assert effective.int == 44
    assert effective.combat_stats.def == mode_value(63, 28)
    assert effective.combat_stats.soft_def == mode_value(48, 47)
    assert effective.combat_stats.mdef == mode_value(40, 19)
    assert effective.combat_stats.soft_mdef == mode_value(49, 67)
  end

  test "derives mode-specific combat bounds and all Homunculus status reader channels" do
    modifiers = %{
      haste_rate: 80,
      vit: 30,
      int: 20,
      def: 15,
      atk_rate: 40,
      hom_aspd_rate: 120,
      flee: 50
    }

    effective = Stats.recompute(state(6_001, %{}), modifiers)

    assert %{str: 31, agi: 20, vit: 48, int: 45, dex: 40, luk: 10} = effective
    assert effective.combat_stats.atk == mode_value(115, 40)
    assert effective.combat_stats.atk_min == mode_value(15, 40)
    assert effective.combat_stats.atk_max == mode_value(31, 71)
    assert effective.combat_stats.def == mode_value(63, 28)
    assert effective.combat_stats.soft_def == mode_value(49, 48)
    assert effective.combat_stats.mdef == mode_value(34, 13)
    assert effective.combat_stats.soft_mdef == mode_value(51, 69)
    assert effective.combat_stats.hit == mode_value(230, 80)
    assert effective.combat_stats.flee == mode_value(114, 110)
    assert effective.combat_stats.critical == 4
    assert effective.combat_stats.critical_rate == 0
    assert effective.combat_stats.matk_min == mode_value(124, 126)
    assert effective.combat_stats.matk_max == mode_value(124, 126)
    assert effective.attack_delay_ms == mode_value(530, 542)
  end

  test "status ATK, status weapon ATK and flat status MATK reach the mode formulas" do
    effective =
      Stats.recompute(state(6_001, %{}), %{batk: 9, batk_rate: 20, watk: 20, matk: 30})

    # Renewal: (115 + 9) + 124 * 20 / 100; weapon ATK never moves the bounds.
    assert effective.combat_stats.atk == mode_value(148, 58)
    assert effective.combat_stats.atk_min == mode_value(15, 60)
    assert effective.combat_stats.atk_max == mode_value(31, 91)
    assert effective.combat_stats.matk == mode_value(128, 80)
    assert effective.combat_stats.matk_max == mode_value(128, 80)
  end

  describe "walk_speed/3" do
    @tag game_mode: :renewal
    test "renewal starts from the owner's current speed and applies the Homunculus's statuses" do
      homunculus = %{state(6_001, %{}) | owner_walk_speed: 150}

      # Owner under Increase AGI (112), the Homunculus under Decrease AGI.
      assert Stats.walk_speed(homunculus, %{movement_speed: 25}, 112) == 140
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal starts from the owner speed copied at its last recalculation" do
      homunculus = %{state(6_001, %{}) | owner_walk_speed: 150}

      assert Stats.walk_speed(homunculus, %{movement_speed: 25}, 112) == 187
    end

    test "a slow slows it and only the strongest haste counts" do
      homunculus = %{state(6_001, %{}) | owner_walk_speed: 150}

      assert Stats.walk_speed(homunculus, %{movement_speed: 300}, 150) == 600
      assert Stats.walk_speed(homunculus, %{haste_rate: 80}, 150) == 60
    end
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

  test "potion HP follows passive growth without compounding and expires with a pool clamp" do
    original = state(6_002, %{8_007 => 4})
    boosted = Stats.recompute(original, %{max_hp: 830, max_sp_item_rate: 14})
    assert boosted.max_hp == 1_910
    assert boosted.max_sp == 200
    assert Stats.recompute(boosted, %{max_hp: 830}).max_hp == 1_910

    expired = Stats.recompute(%{boosted | hp: 1_900})
    assert expired.max_hp == 1_080
    assert expired.hp == 1_080
  end

  defp mode_value(renewal, pre_renewal) do
    %{renewal: renewal, pre_renewal: pre_renewal}[GameMode.mode()]
  end

  defp state(class_id, learned_skills) do
    build(:homunculus_state,
      class_id: class_id,
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
    )
  end
end
