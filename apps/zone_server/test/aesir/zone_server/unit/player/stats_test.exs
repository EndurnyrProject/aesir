defmodule Aesir.ZoneServer.Unit.Player.StatsTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :setup_ets_tables
  setup :verify_on_exit!

  # Real equip.yml ids.
  @sword 1101
  @bow 1701
  @guard 2101
  @cotton_shirt 2301
  @soul_staff 1472
  # Headgear and garment items with known view values.
  @wedding_veil 2206
  @sunglasses 2201
  @flu_mask 2218
  @adventurers_backpack 2576
  # Two-handed bow that has a non-zero view (11) — used for the shield_view bug test.
  @ixion_wing 18_129

  # EQP position bitmasks.
  @right_hand 2
  @left_hand 32
  @both_hand 34
  @armor_pos 16
  @head_top_pos 256
  @head_mid_pos 512
  @head_low_pos 1
  @garment_pos 4

  defp equipped(nameid, equip) do
    %InventoryItem{nameid: nameid, amount: 1, equip: equip, identify: 1}
  end

  describe "from_character/1" do
    test "creates Stats struct from Character model" do
      character = %Character{
        str: 10,
        agi: 15,
        vit: 20,
        int: 25,
        dex: 12,
        luk: 8,
        base_level: 50,
        job_level: 30,
        base_exp: 1000,
        job_exp: 500,
        hp: 800,
        sp: 300,
        # Novice
        class: 0
      }

      stats = Stats.from_character(character)

      assert stats.base_stats.str == 10
      assert stats.base_stats.agi == 15
      assert stats.base_stats.vit == 20
      assert stats.base_stats.int == 25
      assert stats.base_stats.dex == 12
      assert stats.base_stats.luk == 8

      assert stats.progression.base_level == 50
      assert stats.progression.job_level == 30
      assert stats.progression.base_exp == 1000
      assert stats.progression.job_exp == 500

      assert stats.current_state.hp == 800
      assert stats.current_state.sp == 300

      # Should have calculated derived stats
      assert stats.derived_stats.max_hp > 0
      assert stats.derived_stats.max_sp > 0
      assert stats.derived_stats.aspd > 0
    end

    test "from_character carries status_point into progression" do
      character = %Character{
        base_level: 1,
        job_level: 1,
        base_exp: 0,
        job_exp: 0,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        status_point: 25,
        skill_point: 0,
        weapon: 0,
        shield: 0
      }

      stats = Stats.from_character(character)
      assert stats.progression.status_point == 25
    end

    test "initializes empty modifiers" do
      character = %Character{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1, class: 0}
      stats = Stats.from_character(character)

      assert stats.modifiers.equipment == %{}
      assert stats.modifiers.status_effects == %{}
      assert stats.modifiers.job_bonuses == %{}
    end
  end

  describe "calculate_stats/1" do
    test "recalculates all derived stats from base values" do
      stats = %Stats{
        base_stats: %{str: 20, agi: 15, vit: 25, int: 30, dex: 10, luk: 5},
        progression: %{
          base_level: 40,
          job_level: 20,
          base_exp: 500,
          job_exp: 200,
          job_id: 0,
          learned_skills: %{}
        },
        current_state: %{hp: 600, sp: 250},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Should calculate HP based on JobData and VIT
      # JobData.get_base_hp(0, 40) = 235
      # Novice doesn't have job bonuses at level 20, so effective VIT=25
      # With VIT=25: 235 * (1.0 + 25 * 0.01) = 235 * 1.25 = 293.75 -> 293
      assert updated_stats.derived_stats.max_hp == 293

      # Should calculate SP based on JobData and INT
      # JobData.get_base_sp(0, 40) = 50
      # Novice doesn't have job bonuses at level 20, so effective INT=30
      # With INT=30: 50 * (1.0 + 30 * 0.01) = 50 * 1.30 = 65
      assert updated_stats.derived_stats.max_sp == 65
    end

    test "ensures minimum HP/SP values" do
      stats = %Stats{
        base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 1,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        current_state: %{hp: 1, sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      assert updated_stats.derived_stats.max_hp >= 1
      assert updated_stats.derived_stats.max_sp >= 1
    end
  end

  describe "get_effective_stat/2" do
    test "returns base stat when no modifiers" do
      stats = %Stats{
        base_stats: %{str: 15, agi: 20, vit: 10, int: 25, dex: 12, luk: 8},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}},
        equipment: %Equipment{}
      }

      assert Stats.get_effective_stat(stats, :str) == 15
      assert Stats.get_effective_stat(stats, :agi) == 20
      assert Stats.get_effective_stat(stats, :vit) == 10
      assert Stats.get_effective_stat(stats, :int) == 25
      assert Stats.get_effective_stat(stats, :dex) == 12
      assert Stats.get_effective_stat(stats, :luk) == 8
    end

    test "includes all modifier types" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 15, vit: 20, int: 25, dex: 12, luk: 8},
        modifiers: %{
          equipment: %{str: 5, agi: 3},
          status_effects: %{str: 2, vit: -1},
          job_bonuses: %{str: 3, int: 4}
        },
        equipment: %Equipment{}
      }

      # STR: 10 (base) + 5 (equipment) + 2 (status) + 3 (job) = 20
      assert Stats.get_effective_stat(stats, :str) == 20

      # AGI: 15 (base) + 3 (equipment) = 18
      assert Stats.get_effective_stat(stats, :agi) == 18

      # VIT: 20 (base) - 1 (status) = 19
      assert Stats.get_effective_stat(stats, :vit) == 19

      # INT: 25 (base) + 4 (job) = 29
      assert Stats.get_effective_stat(stats, :int) == 29

      # DEX: 12 (base, no modifiers) = 12
      assert Stats.get_effective_stat(stats, :dex) == 12
    end

    test "includes the passive skill bonus for the stat" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 15, vit: 20, int: 25, dex: 12, luk: 8},
        modifiers: %{
          equipment: %{},
          status_effects: %{},
          job_bonuses: %{},
          passive: %{dex: 5}
        },
        equipment: %Equipment{}
      }

      # DEX: 12 (base) + 5 (passive) = 17
      assert Stats.get_effective_stat(stats, :dex) == 17
      # A stat with no passive contribution is unaffected
      assert Stats.get_effective_stat(stats, :str) == 10
    end

    test "handles missing modifiers gracefully" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 15, vit: 20, int: 25, dex: 12, luk: 8},
        modifiers: %{
          equipment: %{str: 5},
          status_effects: %{},
          job_bonuses: %{int: 3}
        },
        equipment: %Equipment{}
      }

      # 10 + 5
      assert Stats.get_effective_stat(stats, :str) == 15
      # 15 + 0
      assert Stats.get_effective_stat(stats, :agi) == 15
      # 25 + 3
      assert Stats.get_effective_stat(stats, :int) == 28
    end
  end

  describe "rAthena HP formula accuracy" do
    test "calculates HP correctly for level 1 character" do
      stats = %Stats{
        base_stats: %{vit: 1, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 1,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 1: JobData.get_base_hp(0, 1) = 40, with VIT=1: 40 * (1.0 + 1*0.01) = 40.4 -> 40
      assert updated_stats.derived_stats.max_hp == 40
    end

    test "calculates HP correctly for higher level character" do
      stats = %Stats{
        base_stats: %{vit: 50, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 75,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 75: JobData.get_base_hp(0, 75) = 410, with VIT=50: 410 * (1.0 + 50*0.01) = 410 * 1.5 = 615
      assert updated_stats.derived_stats.max_hp == 615
    end

    test "calculates HP correctly for max novice level" do
      stats = %Stats{
        base_stats: %{vit: 99, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 99,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 99: JobData.get_base_hp(0, 99) = 530, with VIT=99: 530 * (1.0 + 99*0.01) = 530 * 1.99 = 1054.7 -> 1054
      assert updated_stats.derived_stats.max_hp == 1054
    end
  end

  describe "rAthena SP formula accuracy" do
    test "calculates SP correctly for level 1 character" do
      stats = %Stats{
        base_stats: %{int: 1, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 1,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 1: JobData.get_base_sp(0, 1) = 11, with INT=1: 11 * (1.0 + 1*0.01) = 11.11 -> 11
      assert updated_stats.derived_stats.max_sp == 11
    end

    test "calculates SP correctly for higher level character" do
      stats = %Stats{
        base_stats: %{int: 80, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 60,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 60: JobData.get_base_sp(0, 60) = 70, with INT=80: 70 * (1.0 + 80*0.01) = 70 * 1.8 = 126
      assert updated_stats.derived_stats.max_sp == 126
    end

    test "calculates SP correctly for max novice level" do
      stats = %Stats{
        base_stats: %{int: 99, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{
          base_level: 99,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Novice level 99: JobData.get_base_sp(0, 99) = 109
      # With INT=99: 109 * (1.0 + 99*0.01) = 109 * 1.99 = 216.91 -> 216
      assert updated_stats.derived_stats.max_sp == 216
    end
  end

  describe "modifier system" do
    test "job bonuses remain unchanged (placeholder)" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        progression: %{
          base_level: 1,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.apply_job_bonuses(stats)
      assert result.modifiers.job_bonuses == %{}
    end

    test "equipment modifiers remain unchanged (placeholder)" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.apply_equipment_modifiers(stats)
      assert result == stats
    end

    test "status effects remain unchanged (placeholder)" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.apply_status_effects(stats)
      assert result == stats
    end
  end

  describe "combat stats calculation" do
    test "calculates combat stats based on base stats" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.calculate_combat_stats(stats)

      # With zero stats and level, all values should be zero
      assert result.combat_stats.hit == 0
      assert result.combat_stats.flee == 0
      assert result.combat_stats.critical == 0
      assert result.combat_stats.atk == 0
      assert result.combat_stats.def == 0
    end

    test "applies status effect modifiers to combat stats" do
      # Create stats with status effect modifiers
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{
          equipment: %{},
          status_effects: %{hit: 10, flee: 10, critical: 10, atk: 10, def: 10},
          job_bonuses: %{}
        }
      }

      result = Stats.calculate_combat_stats(stats)

      # Base values are 0, but status effects add 10 to each
      assert result.combat_stats.hit == 10
      assert result.combat_stats.flee == 10
      assert result.combat_stats.critical == 10
      assert result.combat_stats.atk == 10
      assert result.combat_stats.def == 10
    end

    test "folds the passive ATK mastery into atk and exposes passive_atk" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{2 => 5}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: Stats.equipment_from_inventory([equipped(@sword, @right_hand)]),
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.calculate_combat_stats(stats)

      # SM_SWORD (id 2) level 5 with a one-handed sword grants 4 * 5 = 20 ATK
      assert result.combat_stats.passive_atk == 20
      assert result.combat_stats.atk == 20
    end

    test "passive_atk is 0 when the equipped weapon does not match the mastery" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{2 => 5}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: Stats.equipment_from_inventory([equipped(@bow, @both_hand)]),
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.passive_atk == 0
      assert result.combat_stats.atk == 0
    end
  end

  describe "renewal MATK and MDEF" do
    defp caster(base_stats, base_level) do
      %Stats{
        base_stats: base_stats,
        progression: %{base_level: base_level, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }
    end

    test "status MATK follows the renewal formula" do
      stats =
        caster(%{str: 0, agi: 0, vit: 0, int: 40, dex: 30, luk: 30}, 80)

      result = Stats.calculate_combat_stats(stats)

      # INT + INT/2 + DEX/5 + LUK/3 + level/4 = 40 + 20 + 6 + 10 + 20 = 96
      assert result.combat_stats.matk == 96
    end

    test "without a MATK weapon matk_min == matk_max == matk == base_matk" do
      stats = caster(%{str: 0, agi: 0, vit: 0, int: 40, dex: 30, luk: 30}, 80)

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.matk_min == 96
      assert result.combat_stats.matk_max == 96
      assert result.combat_stats.matk == result.combat_stats.matk_max
    end

    test "a flat MATK bonus (cards/armor enchant) raises both matk_min and matk_max" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 40, dex: 30, luk: 30},
        progression: %{base_level: 80, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{matk: 30}, status_effects: %{matk: 20}, job_bonuses: %{}}
      }

      result = Stats.calculate_combat_stats(stats)

      # base 96 + flat (equipment 30 + status 20) on both ends, no variance band
      assert result.combat_stats.matk_min == 146
      assert result.combat_stats.matk_max == 146
      assert result.combat_stats.matk == 146
    end

    test "soft MDEF follows the renewal formula" do
      stats =
        caster(%{str: 0, agi: 0, vit: 20, int: 40, dex: 30, luk: 0}, 80)

      result = Stats.calculate_combat_stats(stats)

      # INT + level/4 + (DEX + VIT)/5 = 40 + 20 + 10 = 70
      assert result.combat_stats.soft_mdef == 70
    end

    test "hard MDEF is 0 without gear or status" do
      stats =
        caster(%{str: 0, agi: 0, vit: 20, int: 40, dex: 30, luk: 0}, 80)

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.mdef == 0
    end

    test "hard MDEF sums status and equipment modifiers" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{mdef: 5}, status_effects: %{mdef: 3}, job_bonuses: %{}}
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.mdef == 8
    end
  end

  describe "derived combat stats (patk/smatk/res/mres/hplus/crate)" do
    test "sums status and equipment modifiers into each slot" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{
          equipment: %{patk: 30, smatk: 30, res: 30, mres: 30, hplus: 30, crate: 30},
          status_effects: %{patk: 20, smatk: 20, res: 20, mres: 20, hplus: 20, crate: 20},
          job_bonuses: %{}
        }
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.patk == 50
      assert result.combat_stats.smatk == 50
      assert result.combat_stats.res == 50
      assert result.combat_stats.mres == 50
      assert result.combat_stats.hplus == 50
      assert result.combat_stats.crate == 50
    end

    test "defaults to 0 with no modifiers" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.patk == 0
      assert result.combat_stats.smatk == 0
      assert result.combat_stats.res == 0
      assert result.combat_stats.mres == 0
      assert result.combat_stats.hplus == 0
      assert result.combat_stats.crate == 0
    end

    test "clamps above 32767 down to 32767" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{
          equipment: %{patk: 20_000, res: 20_000},
          status_effects: %{patk: 20_000, res: 20_000},
          job_bonuses: %{}
        }
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.patk == 32_767
      assert result.combat_stats.res == 32_767
    end

    test "clamps negative values up to 0" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{
          equipment: %{},
          status_effects: %{mres: -50},
          job_bonuses: %{}
        }
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.mres == 0
    end
  end

  describe "equipment_from_inventory/1" do
    test "places each equipped item's nameid at its worn location" do
      equipment =
        Stats.equipment_from_inventory([
          equipped(@sword, @right_hand),
          equipped(@guard, @left_hand),
          equipped(@cotton_shirt, @armor_pos)
        ])

      assert %Equipment{right_hand: @sword, left_hand: @guard, armor: @cotton_shirt} = equipment
    end

    test "a two-handed weapon occupies both hand slots" do
      equipment = Stats.equipment_from_inventory([equipped(@bow, @both_hand)])

      assert %Equipment{right_hand: @bow, left_hand: @bow} = equipment
    end

    test "an empty inventory yields an empty Equipment" do
      assert %Equipment{right_hand: nil, left_hand: nil, armor: nil} =
               Stats.equipment_from_inventory([])
    end

    test "accepts an index-keyed inventory map" do
      equipment = Stats.equipment_from_inventory(%{3 => equipped(@sword, @right_hand)})

      assert %Equipment{right_hand: @sword} = equipment
    end
  end

  describe "weapon_type/1 and shield?/1" do
    test "weapon_type resolves the right-hand item's subtype" do
      equipment = Stats.equipment_from_inventory([equipped(@sword, @right_hand)])
      assert Stats.weapon_type(equipment) == :one_handed_sword
    end

    test "weapon_type is :fist when bare-handed" do
      assert Stats.weapon_type(%Equipment{}) == :fist
    end

    test "shield? is true for a non-weapon left-hand item" do
      equipment = Stats.equipment_from_inventory([equipped(@guard, @left_hand)])
      assert Stats.shield?(equipment) == true
    end

    test "shield? is false for a two-handed weapon in the left hand" do
      equipment = Stats.equipment_from_inventory([equipped(@bow, @both_hand)])
      assert Stats.shield?(equipment) == false
    end

    test "shield? is false when nothing is in the left hand" do
      assert Stats.shield?(%Equipment{}) == false
    end
  end

  describe "calculate_stats/3 with equipped items" do
    defp swordman(equipment_struct, modifier_equipment) do
      %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{
          base_level: 1,
          job_level: 1,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: %{}
        },
        current_state: %{hp: 1, sp: 1},
        equipment: equipment_struct,
        modifiers: %{equipment: modifier_equipment, status_effects: %{}, job_bonuses: %{}}
      }
    end

    test "equipping the Sword (atk 25) raises combat atk by 25 and sets weapon type" do
      sword = equipped(@sword, @right_hand)

      bare = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [])
      armed = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [sword])

      assert armed.combat_stats.atk == bare.combat_stats.atk + 25
      assert Stats.weapon_type(armed.equipment) == :one_handed_sword
    end

    test "removing the weapon reverts the atk bonus and weapon type" do
      sword = equipped(@sword, @right_hand)

      armed = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [sword])
      reverted = Stats.calculate_stats(armed, nil, [])

      assert reverted.combat_stats.atk == 0
      assert Stats.weapon_type(reverted.equipment) == :fist
    end

    test "a known armor's defense adds to combat def" do
      armor = equipped(@cotton_shirt, @armor_pos)

      bare = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [])
      armored = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [armor])

      assert armored.combat_stats.def == bare.combat_stats.def + 10
    end

    test "nil equipped_items leaves equipment and modifiers untouched" do
      preset = Stats.equipment_from_inventory([equipped(@sword, @right_hand)])
      result = Stats.calculate_stats(swordman(preset, %{atk: 99}), nil, nil)

      assert result.equipment == preset
      assert result.modifiers.equipment == %{atk: 99}
    end

    test "equipping Soul Staff (magic_attack 200, weapon_level 3) opens a +-15% MATK band" do
      staff = equipped(@soul_staff, @both_hand)

      bare = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [])
      staffed = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [staff])

      assert bare.combat_stats.matk_min == bare.combat_stats.matk_max

      # rAthena status.cpp:6306: variance = matk * wlv / 10 = 200 * 3 / 10 = 60;
      # min += matk - variance = 140, max += matk + variance = 260
      assert staffed.combat_stats.matk_min == bare.combat_stats.matk_min + 140
      assert staffed.combat_stats.matk_max == bare.combat_stats.matk_max + 260
      assert staffed.combat_stats.matk_min < staffed.combat_stats.matk_max
      assert staffed.combat_stats.matk == staffed.combat_stats.matk_max
    end

    test "patk/smatk/res/mres accumulate across equipped items into combat stats" do
      item_a = %ItemDefinition{
        id: 90_001,
        aegis_name: "test_derived_a",
        name: "Test A",
        patk: 5,
        smatk: 2,
        res: 4,
        mres: 1
      }

      item_b = %ItemDefinition{
        id: 90_002,
        aegis_name: "test_derived_b",
        name: "Test B",
        patk: 3,
        smatk: 6,
        res: 9,
        mres: 7
      }

      stub(ItemManagement, :get_item_by_id, fn
        90_001 -> {:ok, item_a}
        90_002 -> {:ok, item_b}
      end)

      equipped_items = [equipped(90_001, @right_hand), equipped(90_002, @left_hand)]

      result = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, equipped_items)

      assert result.modifiers.equipment.patk == 8
      assert result.modifiers.equipment.smatk == 8
      assert result.modifiers.equipment.res == 13
      assert result.modifiers.equipment.mres == 8

      assert result.combat_stats.patk == 8
      assert result.combat_stats.smatk == 8
      assert result.combat_stats.res == 13
      assert result.combat_stats.mres == 8
    end
  end

  describe "view extractors" do
    test "head_top_view returns item view for equipped head-top" do
      equipment = Stats.equipment_from_inventory([equipped(@wedding_veil, @head_top_pos)])
      assert Stats.head_top_view(equipment) == 44
    end

    test "head_top_view returns 0 for empty slot" do
      assert Stats.head_top_view(%Equipment{}) == 0
    end

    test "head_mid_view returns item view for equipped head-mid" do
      equipment = Stats.equipment_from_inventory([equipped(@sunglasses, @head_mid_pos)])
      assert Stats.head_mid_view(equipment) == 12
    end

    test "head_mid_view returns 0 for empty slot" do
      assert Stats.head_mid_view(%Equipment{}) == 0
    end

    test "head_bottom_view returns item view for equipped head-low" do
      equipment = Stats.equipment_from_inventory([equipped(@flu_mask, @head_low_pos)])
      assert Stats.head_bottom_view(equipment) == 8
    end

    test "head_bottom_view returns 0 for empty slot" do
      assert Stats.head_bottom_view(%Equipment{}) == 0
    end

    test "robe_view returns item view for equipped garment" do
      equipment = Stats.equipment_from_inventory([equipped(@adventurers_backpack, @garment_pos)])
      assert Stats.robe_view(equipment) == 2
    end

    test "robe_view returns 0 for empty slot" do
      assert Stats.robe_view(%Equipment{}) == 0
    end

    test "shield_view returns item view for a real shield" do
      equipment = Stats.equipment_from_inventory([equipped(@guard, @left_hand)])
      assert Stats.shield_view(equipment) == 1
    end

    test "shield_view returns 0 for empty slot" do
      assert Stats.shield_view(%Equipment{}) == 0
    end

    test "shield_view returns 0 when left_hand holds a two-handed weapon" do
      equipment = Stats.equipment_from_inventory([equipped(@ixion_wing, @both_hand)])
      assert Stats.shield_view(equipment) == 0
    end
  end
end
