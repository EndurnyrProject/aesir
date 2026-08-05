defmodule Aesir.ZoneServer.Unit.Player.StatsTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  defmodule AspdIntPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_010,
      name: :test_aspd_int_passive,
      display_name: "Test ASPD/INT Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def aspd_bonus(level, _ctx), do: 40 * level

    @impl Passive
    def int_bonus(level, _ctx), do: 2 * level

    @impl Passive
    def str_bonus(level, _ctx), do: level
  end

  setup :setup_ets_tables
  setup :verify_on_exit!

  # Real equip.yml ids.
  @sword 1101
  @knife 1201
  @mace 1340
  @javelin 1401
  @lance 1410
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

  defp refined(nameid, equip, refine) do
    %InventoryItem{nameid: nameid, amount: 1, equip: equip, identify: 1, refine: refine}
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

    test "loads trait stats, trait_point, and ap into runtime state" do
      # Dragon Knight (trait job) at base level 200 so the recomputed max_ap
      # (base_ap table = 200) is high enough that the loaded ap survives the clamp.
      character = %Character{
        base_level: 200,
        job_level: 1,
        base_exp: 0,
        job_exp: 0,
        class: 4252,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        pow: 30,
        sta: 4,
        wis: 5,
        spl: 6,
        con: 7,
        crt: 8,
        trait_point: 12,
        ap: 5,
        max_ap: 200
      }

      stats = Stats.from_character(character)

      assert stats.base_stats.pow == 30
      assert stats.base_stats.sta == 4
      assert stats.base_stats.wis == 5
      assert stats.base_stats.spl == 6
      assert stats.base_stats.con == 7
      assert stats.base_stats.crt == 8
      assert stats.progression.trait_point == 12
      assert stats.current_state.ap == 5
    end

    test "row 26: a trait job's max_ap equals the base_ap table value at its level" do
      character = %Character{
        base_level: 200,
        job_level: 1,
        class: 4252,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11
      }

      stats = Stats.from_character(character)

      assert stats.derived_stats.max_ap == 200
    end

    test "row 26: a non-trait job's max_ap is 0" do
      character = %Character{
        base_level: 99,
        job_level: 50,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11
      }

      stats = Stats.from_character(character)

      assert stats.derived_stats.max_ap == 0
    end

    test "ap is clamped down to max_ap (trait job over cap, non-trait job to 0)" do
      over_cap = %Character{
        base_level: 200,
        job_level: 1,
        class: 4252,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        ap: 9999
      }

      non_trait = %Character{
        base_level: 99,
        job_level: 50,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        ap: 5
      }

      assert Stats.from_character(over_cap).current_state.ap == 200
      assert Stats.from_character(non_trait).current_state.ap == 0
    end

    test "denormalizes the option riding bit into stats.riding" do
      mounted = %Character{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1, class: 0, option: 32}
      grounded = %Character{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1, class: 0, option: 0}

      assert Stats.from_character(mounted).riding == true
      assert Stats.from_character(grounded).riding == false
    end

    test "initializes empty modifiers" do
      character = %Character{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1, class: 0}
      stats = Stats.from_character(character)

      assert stats.modifiers.equipment == %{}
      assert stats.modifiers.status_effects == %{}

      assert stats.modifiers.job_bonuses ==
               %{
                 str: 0,
                 agi: 0,
                 vit: 0,
                 int: 0,
                 dex: 0,
                 luk: 0,
                 pow: 0,
                 sta: 0,
                 wis: 0,
                 spl: 0,
                 con: 0,
                 crt: 0
               }
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

    test "aggregates trait stats (base + job bonus) like classic stats" do
      stats = %Stats{
        base_stats: %{
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1,
          pow: 30,
          sta: 4,
          wis: 5,
          spl: 6,
          con: 7,
          crt: 8
        },
        modifiers: %{
          equipment: %{},
          status_effects: %{},
          job_bonuses: %{pow: 5}
        },
        equipment: %Equipment{}
      }

      # POW: 30 (base) + 5 (job bonus)
      assert Stats.get_effective_stat(stats, :pow) == 35
      # No job bonus -> equals base
      assert Stats.get_effective_stat(stats, :sta) == 4
      assert Stats.get_effective_stat(stats, :wis) == 5
      assert Stats.get_effective_stat(stats, :spl) == 6
      assert Stats.get_effective_stat(stats, :con) == 7
      assert Stats.get_effective_stat(stats, :crt) == 8
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
    test "job bonuses resolve to the cumulative running total for the job level" do
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

      assert result.modifiers.job_bonuses ==
               %{
                 str: 0,
                 agi: 0,
                 vit: 0,
                 int: 0,
                 dex: 0,
                 luk: 0,
                 pow: 0,
                 sta: 0,
                 wis: 0,
                 spl: 0,
                 con: 0,
                 crt: 0
               }
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
      refute result.combat_stats.ignore_size_penalty
      refute result.combat_stats.max_weapon_damage
    end

    test "folds physical damage flags from status modifiers" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{
          equipment: %{},
          status_effects: %{ignore_size_penalty: true, max_weapon_damage: true},
          job_bonuses: %{}
        }
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.ignore_size_penalty
      assert result.combat_stats.max_weapon_damage
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

    test "converts Mace Mastery's internal critical tenths at the display boundary" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{65 => 5}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: Stats.equipment_from_inventory([equipped(@mace, @right_hand)]),
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.critical == 5
    end

    test "Spear Mastery grants +4 per level on foot with a one-handed spear" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{55 => 10}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: Stats.equipment_from_inventory([equipped(@javelin, @right_hand)]),
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}},
        riding: false
      }

      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.passive_atk == 40
      assert result.combat_stats.atk == 40
    end

    test "Spear Mastery grants +5 per level while riding, one-handed or two-handed spear" do
      one_handed = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{55 => 10}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: Stats.equipment_from_inventory([equipped(@javelin, @right_hand)]),
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}},
        riding: true
      }

      two_handed = %{
        one_handed
        | equipment: Stats.equipment_from_inventory([equipped(@lance, @both_hand)])
      }

      assert Stats.calculate_combat_stats(one_handed).combat_stats.atk == 50
      assert Stats.calculate_combat_stats(two_handed).combat_stats.atk == 50
    end

    test "Spear Mastery grants no bonus with a non-spear weapon, mounted or not" do
      stats = %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{55 => 10}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: Stats.equipment_from_inventory([equipped(@sword, @right_hand)]),
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}},
        riding: true
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

  describe "trait-stat derivation (SP-B, formula rows 1-11)" do
    defp trait_stats(base_stats) do
      %Stats{
        base_stats: base_stats,
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}, passive: %{}}
      }
    end

    @zero %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0}

    test "row 1: POW 10 raises base ATK by 50 and P.Atk by 3" do
      result = @zero |> Map.put(:pow, 10) |> trait_stats() |> Stats.calculate_combat_stats()

      assert result.combat_stats.atk == 50
      assert result.combat_stats.patk == 3
    end

    test "row 2: SPL 7 raises base MATK by 35 and S.MAtk by 2" do
      result = @zero |> Map.put(:spl, 7) |> trait_stats() |> Stats.calculate_combat_stats()

      assert result.combat_stats.matk == 35
      assert result.combat_stats.smatk == 2
    end

    test "rows 3-6: CON 7 raises P.Atk/S.MAtk by 1 and HIT/FLEE by 14" do
      result = @zero |> Map.put(:con, 7) |> trait_stats() |> Stats.calculate_combat_stats()

      assert result.combat_stats.patk == 1
      assert result.combat_stats.smatk == 1
      assert result.combat_stats.hit == 14
      assert result.combat_stats.flee == 14
    end

    test "row 7: STA 10 gives Res 25 (div truncates before *5)" do
      result = @zero |> Map.put(:sta, 10) |> trait_stats() |> Stats.calculate_combat_stats()

      assert result.combat_stats.res == 25
    end

    test "row 7: STA 12 gives Res 32" do
      result = @zero |> Map.put(:sta, 12) |> trait_stats() |> Stats.calculate_combat_stats()

      assert result.combat_stats.res == 32
    end

    test "row 8: WIS 10 gives MRes 25" do
      result = @zero |> Map.put(:wis, 10) |> trait_stats() |> Stats.calculate_combat_stats()

      assert result.combat_stats.mres == 25
    end

    test "rows 9-10: CRT 10 gives HPlus 10 and CRate 3" do
      result = @zero |> Map.put(:crt, 10) |> trait_stats() |> Stats.calculate_combat_stats()

      assert result.combat_stats.hplus == 10
      assert result.combat_stats.crate == 3
    end

    test "row 11: CRT never feeds the classic critical stat" do
      base = %{@zero | luk: 30}
      no_crt = base |> trait_stats() |> Stats.calculate_combat_stats()
      high_crt = base |> Map.put(:crt, 100) |> trait_stats() |> Stats.calculate_combat_stats()

      assert no_crt.combat_stats.critical == 10
      assert high_crt.combat_stats.critical == no_crt.combat_stats.critical
    end
  end

  describe "equipment reductions" do
    test "worn items carry card slots and the equip location bitmask" do
      character = %Character{
        id: 1,
        name: "Forger",
        account_id: 1,
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        class: 0,
        base_level: 1,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11
      }

      item = %InventoryItem{
        nameid: @sword,
        amount: 1,
        equip: @right_hand,
        identify: 1,
        refine: 7,
        card0: 255,
        card1: 1_282,
        card2: 3,
        card3: 4
      }

      player = PlayerState.new(character)
      stats = Stats.apply_equipment_modifiers(player.stats, [item])

      # Forged metadata lives on `worn_items`, the stat/bonus reduction. `equip`
      # is carried alongside so a consumer can tell which slot an entry came
      # from without a second reduction.
      assert [
               %{
                 nameid: @sword,
                 refine: 7,
                 equip: @right_hand,
                 card0: 255,
                 card1: 1_282,
                 card2: 3,
                 card3: 4
               }
             ] = stats.worn_items

      # `Equipment` stays a bare nameid-per-location lookup: it resolves looks
      # and weapon type, and deliberately carries no item metadata.
      assert stats.equipment.right_hand == @sword
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

      assert %Equipment{
               right_hand: @sword,
               left_hand: @guard,
               armor: @cotton_shirt
             } = equipment
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

  describe "validate_shield/1 and shield_stats/2" do
    test "validate_shield is :ok with a shield equipped" do
      equipment = Stats.equipment_from_inventory([equipped(@guard, @left_hand)])
      assert Stats.validate_shield(equipment) == :ok
    end

    test "validate_shield errors with no shield" do
      assert Stats.validate_shield(%Equipment{}) == {:error, :requires_shield}
    end

    test "validate_shield errors when the left hand holds a two-handed weapon" do
      equipment = Stats.equipment_from_inventory([equipped(@bow, @both_hand)])
      assert Stats.validate_shield(equipment) == {:error, :requires_shield}
    end

    test "shield_stats returns the item-DB weight and the equipped row's refine" do
      row = refined(@guard, @left_hand, 7)
      equipment = Stats.equipment_from_inventory([row])

      # Guard (id 2101) weighs 300 raw units in the item DB.
      assert Stats.shield_stats(equipment, [row]) == {300, 7}
    end

    test "shield_stats is nil when no shield is worn" do
      assert Stats.shield_stats(%Equipment{}, []) == nil
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

    test "equipping the Sword (atk 25) raises combat atk by 25 and publishes its right hand" do
      sword = equipped(@sword, @right_hand)

      bare = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [])
      armed = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [sword])

      assert armed.combat_stats.atk == bare.combat_stats.atk + 25
      assert Stats.weapon_type(armed.equipment) == :one_handed_sword

      assert armed.right_hand == %WeaponHand{
               item_id: @sword,
               subtype: :one_handed_sword,
               element: :neutral,
               base_atk: 25,
               refine_atk: 0,
               overrefine_band: 0,
               slot: :right_hand
             }

      assert armed.left_hand == nil
    end

    test "a left-only dagger publishes only its left hand without changing aggregate ATK" do
      armed =
        Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [equipped(@knife, @left_hand)])

      assert armed.combat_stats.atk == 17
      assert armed.right_hand == nil

      assert %WeaponHand{
               item_id: @knife,
               subtype: :dagger,
               base_atk: 17,
               slot: :left_hand
             } = armed.left_hand
    end

    test "dual weapons keep base, refine, overrefine, and element local to each hand" do
      right = %ItemDefinition{
        id: 90_301,
        aegis_name: "right_dagger",
        name: "Right Dagger",
        type: :weapon,
        subtype: :dagger,
        weapon_level: 4,
        attack: 40,
        attack_element: :fire
      }

      left = %ItemDefinition{
        id: 90_302,
        aegis_name: "left_dagger",
        name: "Left Dagger",
        type: :weapon,
        subtype: :dagger,
        weapon_level: 3,
        attack: 17,
        attack_element: :wind
      }

      stub(ItemManagement, :get_item_by_id, fn
        90_301 -> {:ok, right}
        90_302 -> {:ok, left}
      end)

      stub(RefineDatabase, :level_info, fn
        :weapon, 4, 7 -> %{bonus: 500, randombonus_max: 200}
        :weapon, 3, 8 -> %{bonus: 900, randombonus_max: 400}
      end)

      armed =
        swordman(%Equipment{}, %{})
        |> Stats.apply_equipment_modifiers([
          refined(90_301, @right_hand, 7),
          refined(90_302, @left_hand, 8)
        ])
        |> Stats.calculate_combat_stats()

      assert armed.combat_stats.atk == 71

      assert armed.right_hand == %WeaponHand{
               item_id: 90_301,
               subtype: :dagger,
               element: :fire,
               base_atk: 40,
               refine_atk: 5,
               overrefine_band: 2,
               slot: :right_hand
             }

      assert armed.left_hand == %WeaponHand{
               item_id: 90_302,
               subtype: :dagger,
               element: :wind,
               base_atk: 17,
               refine_atk: 9,
               overrefine_band: 4,
               slot: :left_hand
             }
    end

    test "removing the weapon reverts the atk bonus and weapon type" do
      sword = equipped(@sword, @right_hand)

      armed = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [sword])
      reverted = Stats.calculate_stats(armed, nil, [])

      assert reverted.combat_stats.atk == 0
      assert Stats.weapon_type(reverted.equipment) == :fist
    end

    test "a Katar doubles final CRIT until it is removed" do
      base =
        swordman(%Equipment{}, %{})
        |> put_in([Access.key!(:base_stats), Access.key!(:luk)], 30)
        |> put_in([Access.key!(:modifiers), Access.key!(:status_effects)], %{
          critical: 2,
          critical_rate: 50
        })

      bare = base |> Stats.apply_equipment_modifiers([]) |> Stats.calculate_combat_stats()

      armed =
        base
        |> Stats.apply_equipment_modifiers([equipped(1250, @both_hand)])
        |> Stats.calculate_combat_stats()

      reverted = armed |> Stats.apply_equipment_modifiers([]) |> Stats.calculate_combat_stats()

      assert bare.combat_stats.critical == 18
      assert armed.combat_stats.critical == 36
      assert armed.right_hand.subtype == :katar
      assert armed.left_hand == nil
      assert reverted.combat_stats.critical == bare.combat_stats.critical
      assert reverted.right_hand == nil
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

    test "a level-up recompute refolds level-gated on_equip programs from the worn cache" do
      gated = %ItemDefinition{
        id: 90_120,
        aegis_name: "test_level_gated",
        name: "Level Gated",
        on_equip: [
          {:bonus, :atk, {:div, :base_level, 10}},
          {:if, {:>, :base_level, 99}, [{:bonus, :atk_rate, 10}], []}
        ]
      }

      stub(ItemManagement, :get_item_by_id, fn 90_120 -> {:ok, gated} end)

      worn =
        Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [equipped(90_120, @armor_pos)])

      assert worn.modifiers.equipment.atk == 0
      refute Map.has_key?(worn.modifiers.equipment, :atk_rate)

      leveled =
        %{worn | progression: %{worn.progression | base_level: 100}}
        |> Stats.calculate_stats()

      assert leveled.modifiers.equipment.atk == 10
      assert leveled.modifiers.equipment.atk_rate == 10
    end

    test "equipping Soul Staff (magic_attack 200, weapon_level 3) opens a +-15% MATK band" do
      staff = equipped(@soul_staff, @both_hand)

      bare = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [])
      staffed = Stats.calculate_stats(swordman(%Equipment{}, %{}), nil, [staff])

      assert bare.combat_stats.matk_min == bare.combat_stats.matk_max

      # rAthena status.cpp:6306: variance = matk * wlv / 10 = 200 * 3 / 10 = 60;
      # weapon band contributes min += matk - variance = 140, max += matk +
      # variance = 260. Soul Staff's `on_equip` (bonus bInt,5) additionally lifts
      # base MATK by 7 (INT + INT/2 delta), shifting both ends equally.
      assert staffed.combat_stats.matk_min == bare.combat_stats.matk_min + 147
      assert staffed.combat_stats.matk_max == bare.combat_stats.matk_max + 267
      assert staffed.combat_stats.matk_min < staffed.combat_stats.matk_max
      assert staffed.combat_stats.matk == staffed.combat_stats.matk_max
    end

    test "patk/smatk/res/mres accumulate across equipped items into combat stats" do
      item_a = %ItemDefinition{
        id: 90_001,
        aegis_name: "test_derived_a",
        name: "Test A",
        on_equip: [
          {:bonus, :patk, 5},
          {:bonus, :smatk, 2},
          {:bonus, :res, 4},
          {:bonus, :mres, 1}
        ]
      }

      item_b = %ItemDefinition{
        id: 90_002,
        aegis_name: "test_derived_b",
        name: "Test B",
        on_equip: [
          {:bonus, :patk, 3},
          {:bonus, :smatk, 6},
          {:bonus, :res, 9},
          {:bonus, :mres, 7}
        ]
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

  describe "equipment refine bonuses" do
    # Goes through apply_equipment_modifiers + calculate_combat_stats directly
    # (skipping calculate_derived_stats/ASPD, which needs a real job/weapon
    # ASPD table entry irrelevant to refine bonuses, e.g. novice+bow has none).
    defp with_equipped(item) do
      swordman(%Equipment{}, %{})
      |> Stats.apply_equipment_modifiers([item])
      |> Stats.calculate_combat_stats()
    end

    test "a refined weapon adds bonus/100 atk and randombonus_max/100 overrefine band" do
      weapon = %ItemDefinition{
        id: 90_101,
        aegis_name: "test_weapon",
        name: "Test Weapon",
        type: :weapon,
        subtype: :one_handed_sword,
        weapon_level: 4,
        attack: 10
      }

      stub(ItemManagement, :get_item_by_id, fn 90_101 -> {:ok, weapon} end)

      stub(RefineDatabase, :level_info, fn :weapon, 4, 7 ->
        %{bonus: 700, randombonus_max: 300}
      end)

      item = refined(90_101, @right_hand, 7)
      result = with_equipped(item)

      # rAthena status.cpp:3956: atk2 += bonus/100 = 700/100 = 7, on top of the flat 10.
      assert result.combat_stats.atk == 10 + 7
      # randombonus_max/100 = 300/100 = 3.
      assert result.combat_stats.overrefine_band == 3
      # Non-bow refine MATK lands in both ends of the wmatk band.
      assert result.modifiers.equipment.wmatk_min == 7
      assert result.modifiers.equipment.wmatk_max == 7
    end

    test "a bow's refine adds atk but not matk" do
      bow = %ItemDefinition{
        id: 90_102,
        aegis_name: "test_bow",
        name: "Test Bow",
        type: :weapon,
        subtype: :bow,
        weapon_level: 4
      }

      stub(ItemManagement, :get_item_by_id, fn 90_102 -> {:ok, bow} end)
      stub(RefineDatabase, :level_info, fn :weapon, 4, 5 -> %{bonus: 500, randombonus_max: 0} end)

      item = refined(90_102, @both_hand, 5)
      result = with_equipped(item)

      assert result.combat_stats.atk == 5
      assert result.modifiers.equipment.wmatk_min == 0
      assert result.modifiers.equipment.wmatk_max == 0
    end

    test "a refined armor adds (bonus+50)/100 def" do
      armor = %ItemDefinition{
        id: 90_103,
        aegis_name: "test_armor",
        name: "Test Armor",
        type: :armor,
        armor_level: 4,
        defense: 5
      }

      stub(ItemManagement, :get_item_by_id, fn 90_103 -> {:ok, armor} end)
      stub(RefineDatabase, :level_info, fn :armor, 4, 3 -> %{bonus: 250} end)

      item = refined(90_103, @armor_pos, 3)
      result = with_equipped(item)

      # (refine_def + 50) / 100 = (250 + 50) / 100 = 3, on top of the flat 5.
      assert result.combat_stats.def == 5 + 3
      assert result.combat_stats.res == 0
      assert result.combat_stats.mres == 0
    end

    test "a wlv5 weapon's refine grants patk/smatk riders" do
      wlv5 = %ItemDefinition{
        id: 90_104,
        aegis_name: "test_wlv5",
        name: "Test Wlv5",
        type: :weapon,
        subtype: :one_handed_sword,
        weapon_level: 5
      }

      stub(ItemManagement, :get_item_by_id, fn 90_104 -> {:ok, wlv5} end)
      stub(RefineDatabase, :level_info, fn :weapon, 5, 10 -> %{bonus: 0, randombonus_max: 0} end)

      item = refined(90_104, @right_hand, 10)
      result = with_equipped(item)

      assert result.combat_stats.patk == 20
      assert result.combat_stats.smatk == 20
    end

    test "a non-wlv5 weapon's refine grants no patk/smatk rider" do
      wlv4 = %ItemDefinition{
        id: 90_108,
        aegis_name: "test_wlv4",
        name: "Test Wlv4",
        type: :weapon,
        subtype: :one_handed_sword,
        weapon_level: 4
      }

      stub(ItemManagement, :get_item_by_id, fn 90_108 -> {:ok, wlv4} end)
      stub(RefineDatabase, :level_info, fn :weapon, 4, 10 -> %{bonus: 0, randombonus_max: 0} end)

      item = refined(90_108, @right_hand, 10)
      result = with_equipped(item)

      assert result.combat_stats.patk == 0
      assert result.combat_stats.smatk == 0
    end

    test "an armor-lv2 refine grants res/mres riders" do
      armor2 = %ItemDefinition{
        id: 90_105,
        aegis_name: "test_armorlv2",
        name: "Test Armor Lv2",
        type: :armor,
        armor_level: 2
      }

      stub(ItemManagement, :get_item_by_id, fn 90_105 -> {:ok, armor2} end)
      stub(RefineDatabase, :level_info, fn :armor, 2, 10 -> %{bonus: 0} end)

      item = refined(90_105, @armor_pos, 10)
      result = with_equipped(item)

      assert result.combat_stats.res == 20
      assert result.combat_stats.mres == 20
    end

    test "refine == 0 adds no refine bonus" do
      weapon = %ItemDefinition{
        id: 90_106,
        aegis_name: "test_unrefined",
        name: "Test Unrefined",
        type: :weapon,
        subtype: :one_handed_sword,
        weapon_level: 4,
        attack: 10
      }

      stub(ItemManagement, :get_item_by_id, fn 90_106 -> {:ok, weapon} end)

      item = refined(90_106, @right_hand, 0)
      result = with_equipped(item)

      assert result.combat_stats.atk == 10
      assert result.combat_stats.overrefine_band == 0
    end

    test "a missing refine.yml entry adds no refine bonus" do
      weapon = %ItemDefinition{
        id: 90_107,
        aegis_name: "test_nilinfo",
        name: "Test Nil Info",
        type: :weapon,
        subtype: :one_handed_sword,
        weapon_level: 4,
        attack: 10
      }

      stub(ItemManagement, :get_item_by_id, fn 90_107 -> {:ok, weapon} end)
      stub(RefineDatabase, :level_info, fn :weapon, 4, 7 -> nil end)

      item = refined(90_107, @right_hand, 7)
      result = with_equipped(item)

      assert result.combat_stats.atk == 10
      assert result.combat_stats.overrefine_band == 0
    end
  end

  describe "on_equip script bonuses" do
    defp scripted_item(id, fields) do
      Map.merge(
        %ItemDefinition{id: id, aegis_name: "scripted_#{id}", name: "Scripted #{id}"},
        Map.new(fields)
      )
    end

    test "folds an on_equip program alongside the flat attack column, no double-count" do
      item = scripted_item(90_201, attack: 10, on_equip: [{:bonus, :atk, 5}])
      stub(ItemManagement, :get_item_by_id, fn 90_201 -> {:ok, item} end)

      result = with_equipped(equipped(90_201, @right_hand))

      # flat attack 10 + script atk 5, summed once into the same :atk slot
      assert result.modifiers.equipment.atk == 15
      assert result.combat_stats.atk == 15
    end

    test "a script-only key not pre-seeded in the accumulator still lands" do
      item = scripted_item(90_205, on_equip: [{:bonus, :str, 3}])
      stub(ItemManagement, :get_item_by_id, fn 90_205 -> {:ok, item} end)

      result = with_equipped(equipped(90_205, @armor_pos))

      assert result.modifiers.equipment.str == 3
      # and it feeds every STR-derived stat: base ATK = STR + level/4 = 3
      assert result.combat_stats.atk == 3
    end

    test "equipment :hit/:flee/:critical from on_equip reach combat_stats" do
      item =
        scripted_item(90_202,
          on_equip: [{:bonus, :hit, 7}, {:bonus, :flee, 5}, {:bonus, :critical, 4}]
        )

      stub(ItemManagement, :get_item_by_id, fn 90_202 -> {:ok, item} end)

      result = with_equipped(equipped(90_202, @armor_pos))

      assert result.combat_stats.hit == 7
      assert result.combat_stats.flee == 5
      assert result.combat_stats.critical == 4
    end

    test "an on_equip :pow bonus raises patk and base ATK via the SP-B derivation" do
      item = scripted_item(90_203, on_equip: [{:bonus, :pow, 3}])
      stub(ItemManagement, :get_item_by_id, fn 90_203 -> {:ok, item} end)

      result = with_equipped(equipped(90_203, @armor_pos))

      # POW 3 -> base ATK 5*3 = 15; patk = div(pow_eff, 3) = div(3, 3) = 1
      assert result.combat_stats.atk == 15
      assert result.combat_stats.patk == 1
    end

    test "a refine-scaled on_equip program evaluates against the item's refine" do
      item = scripted_item(90_204, on_equip: [{:bonus, :critical, :refine}])
      stub(ItemManagement, :get_item_by_id, fn 90_204 -> {:ok, item} end)

      unrefined = with_equipped(refined(90_204, @armor_pos, 0))
      refined_7 = with_equipped(refined(90_204, @armor_pos, 7))

      assert unrefined.combat_stats.critical == 0
      assert refined_7.combat_stats.critical == 7
    end

    defp with_equipped_items(items) do
      swordman(%Equipment{}, %{})
      |> Stats.apply_equipment_modifiers(items)
      |> Stats.calculate_combat_stats()
    end

    test "two items granting the same tuple bonus stack additively" do
      weapon = scripted_item(90_206, on_equip: [{:bonus, {:addrace, :brute}, 20}])
      shield = scripted_item(90_207, on_equip: [{:bonus, {:addrace, :brute}, 15}])

      stub(ItemManagement, :get_item_by_id, fn
        90_206 -> {:ok, weapon}
        90_207 -> {:ok, shield}
      end)

      both =
        with_equipped_items([
          equipped(90_206, @right_hand),
          equipped(90_207, @left_hand)
        ])

      assert both.modifiers.equipment[{:addrace, :brute}] == 35

      weapon_only = with_equipped_items([equipped(90_206, @right_hand)])
      assert weapon_only.modifiers.equipment[{:addrace, :brute}] == 20

      unequipped = with_equipped_items([])
      refute Map.has_key?(unequipped.modifiers.equipment, {:addrace, :brute})
    end

    test "bAllStats raises every primary stat but leaves the trait stats alone" do
      item = scripted_item(90_210, on_equip: [{:bonus, :all_stats, 3}])
      stub(ItemManagement, :get_item_by_id, fn 90_210 -> {:ok, item} end)

      result = with_equipped(equipped(90_210, @armor_pos))

      for stat <- [:str, :agi, :vit, :int, :dex, :luk] do
        assert Stats.get_effective_stat(result, stat) == 3
      end

      for trait <- [:pow, :sta, :wis, :spl, :con, :crt] do
        assert Stats.get_effective_stat(result, trait) == 0
      end

      # STR 3 flows into base ATK = trunc(STR + level/4) = 3; POW stays 0 so patk is 0.
      assert result.combat_stats.atk == 3
      assert result.combat_stats.patk == 0
    end

    test "bAtkRate scales base ATK only, after the STR derivation" do
      item = scripted_item(90_211, on_equip: [{:bonus, :str, 4}, {:bonus, :atk_rate, 50}])
      stub(ItemManagement, :get_item_by_id, fn 90_211 -> {:ok, item} end)

      result = with_equipped(equipped(90_211, @armor_pos))

      # base ATK = trunc(4 + 1/4) = 4, then +50% -> div(4 * 150, 100) = 6
      assert result.combat_stats.atk == 6
    end

    test "bMatkRate scales the whole MATK band but not the heal band" do
      item = scripted_item(90_212, on_equip: [{:bonus, :int, 10}, {:bonus, :matk_rate, 50}])
      stub(ItemManagement, :get_item_by_id, fn 90_212 -> {:ok, item} end)

      result = with_equipped(equipped(90_212, @armor_pos))

      # base MATK = INT + INT/2 = 15, then +50% -> div(15 * 150, 100) = 22
      assert result.combat_stats.matk_max == 22
      assert result.combat_stats.matk_min == 22
      # the renewal heal band excludes the item rate
      assert result.combat_stats.heal_matk_max == 15
    end

    test "bAspdRate accumulates as a delta off the neutral 100 rate" do
      item = scripted_item(90_213, on_equip: [{:bonus, :aspd_rate, 10}])
      stub(ItemManagement, :get_item_by_id, fn 90_213 -> {:ok, item} end)

      result = with_equipped(equipped(90_213, @armor_pos))

      assert result.modifiers.equipment.aspd_rate == 110
    end

    test "two items each granting bAspdRate stack off the same neutral base" do
      first = scripted_item(90_214, on_equip: [{:bonus, :aspd_rate, 10}])
      second = scripted_item(90_215, on_equip: [{:bonus, :aspd_rate, 5}])

      stub(ItemManagement, :get_item_by_id, fn
        90_214 -> {:ok, first}
        90_215 -> {:ok, second}
      end)

      result =
        with_equipped_items([equipped(90_214, @right_hand), equipped(90_215, @left_hand)])

      assert result.modifiers.equipment.aspd_rate == 115
    end

    test "a :set instruction stores the constant and the last equipped item wins" do
      fire = scripted_item(90_216, on_equip: [{:set, :atk_ele, :fire}])
      wind = scripted_item(90_217, on_equip: [{:set, :atk_ele, :wind}])

      stub(ItemManagement, :get_item_by_id, fn
        90_216 -> {:ok, fire}
        90_217 -> {:ok, wind}
      end)

      one = with_equipped_items([equipped(90_216, @right_hand)])
      assert one.modifiers.equipment.atk_ele == :fire

      # Constants overwrite rather than sum, so the last item folded in wins. The
      # fold order is the equipped-item order, which is only meaningful for a list
      # — the session passes a map, so with two elemental sources the winner is
      # arbitrary. rAthena is equally order-dependent here.
      both = with_equipped_items([equipped(90_216, @right_hand), equipped(90_217, @left_hand)])
      assert both.modifiers.equipment.atk_ele == :wind
    end

    test "bSpeedRate does not stack across items — the strongest one wins" do
      boots = scripted_item(90_218, on_equip: [{:bonus, :movement_speed, 25}])
      cape = scripted_item(90_219, on_equip: [{:bonus, :movement_speed, 10}])

      stub(ItemManagement, :get_item_by_id, fn
        90_218 -> {:ok, boots}
        90_219 -> {:ok, cape}
      end)

      both = with_equipped_items([equipped(90_218, @right_hand), equipped(90_219, @left_hand)])
      assert both.modifiers.equipment.movement_speed == 25

      reversed =
        with_equipped_items([equipped(90_219, @left_hand), equipped(90_218, @right_hand)])

      assert reversed.modifiers.equipment.movement_speed == 25
    end

    test "bFlee2 reaches perfect dodge in the per-mille units the roll uses" do
      item = scripted_item(90_220, on_equip: [{:bonus, :perfect_dodge, 30}])
      stub(ItemManagement, :get_item_by_id, fn 90_220 -> {:ok, item} end)

      result = with_equipped(equipped(90_220, @armor_pos))

      assert result.combat_stats.perfect_dodge == 30
    end

    test "bSplashRange does not stack across items — the widest one wins" do
      weapon = scripted_item(90_222, on_equip: [{:bonus, :splash_range, 1}])
      shield = scripted_item(90_223, on_equip: [{:bonus, :splash_range, 1}])

      stub(ItemManagement, :get_item_by_id, fn
        90_222 -> {:ok, weapon}
        90_223 -> {:ok, shield}
      end)

      both = with_equipped_items([equipped(90_222, @right_hand), equipped(90_223, @left_hand)])

      assert both.modifiers.equipment.splash_range == 1
    end

    test "both bHPDrainRate halves sum across items" do
      weapon =
        scripted_item(90_224,
          on_equip: [{:bonus, :hp_drain_rate, 50}, {:bonus, :hp_drain_percent, 5}]
        )

      shield =
        scripted_item(90_225,
          on_equip: [{:bonus, :hp_drain_rate, 30}, {:bonus, :hp_drain_percent, 1}]
        )

      stub(ItemManagement, :get_item_by_id, fn
        90_224 -> {:ok, weapon}
        90_225 -> {:ok, shield}
      end)

      both = with_equipped_items([equipped(90_224, @right_hand), equipped(90_225, @left_hand)])

      assert both.modifiers.equipment.hp_drain_rate == 80
      assert both.modifiers.equipment.hp_drain_percent == 6
    end

    test "bHealPower lands on its own equipment key, separate from hplus" do
      item = scripted_item(90_221, on_equip: [{:bonus, :heal_power, 15}])
      stub(ItemManagement, :get_item_by_id, fn 90_221 -> {:ok, item} end)

      result = with_equipped(equipped(90_221, @armor_pos))

      assert Stats.get_equipment_modifier(result, :heal_power) == 15
      assert result.combat_stats.hplus == 0
    end

    test "bAddItemHealRate is exposed through the item heal rate reader" do
      stats = %Stats{modifiers: %Modifiers{equipment: %{item_heal_rate: 20}}}

      assert Stats.get_item_heal_rate(stats) == 20
    end
  end

  describe "hp/sp capacity equipment bonuses" do
    defp level_75_stats(equipment_modifiers) do
      %Stats{
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
        modifiers: %{
          equipment: equipment_modifiers,
          status_effects: %{},
          job_bonuses: %{}
        }
      }
      |> Stats.calculate_stats()
    end

    test "the level-75 baseline is unchanged with no capacity bonuses" do
      assert level_75_stats(%{}).derived_stats.max_hp == 615
    end

    test "bMaxHP adds flat HP on top of the VIT-scaled base" do
      assert level_75_stats(%{max_hp: 1000}).derived_stats.max_hp == 1615
    end

    test "bMaxHPrate scales the post-flat total" do
      # 615 * 1.10 = 676.5 -> 676
      assert level_75_stats(%{max_hp_rate: 10}).derived_stats.max_hp == 676
    end

    test "bMaxHP applies before bMaxHPrate, matching the renewal order" do
      # (615 + 1000) * 1.10 = 1776.5 -> 1776
      assert level_75_stats(%{max_hp: 1000, max_hp_rate: 10}).derived_stats.max_hp == 1776
    end

    test "bMaxSP adds flat SP and bMaxSPrate scales the total" do
      baseline = level_75_stats(%{}).derived_stats.max_sp

      assert level_75_stats(%{max_sp: 200}).derived_stats.max_sp == baseline + 200
      assert level_75_stats(%{max_sp_rate: 10}).derived_stats.max_sp == trunc(baseline * 1.10)
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

  defp status_stats(status_effects, current \\ %{hp: 1, sp: 1}) do
    %Stats{
      base_stats: %{str: 10, agi: 30, vit: 25, int: 30, dex: 20, luk: 10},
      progression: %{
        base_level: 50,
        job_level: 25,
        base_exp: 0,
        job_exp: 0,
        job_id: 0,
        learned_skills: %{}
      },
      current_state: current,
      equipment: %Equipment{},
      modifiers: %{equipment: %{}, status_effects: status_effects, job_bonuses: %{}}
    }
    |> Stats.calculate_stats()
  end

  describe "status ASPD modifiers" do
    test "flat :aspd status scales with AGI / 200" do
      base_stats = status_stats(%{})
      base = base_stats.derived_stats.aspd
      agi = Stats.get_effective_stat(base_stats, :agi)

      # A flat bonus of 200 contributes exactly 200 * AGI / 200 = AGI points.
      boosted = status_stats(%{aspd: 200}).derived_stats.aspd

      assert boosted == min(base + agi, 193)
      assert boosted > base
    end

    test "flat :aspd is clamped at 193" do
      assert status_stats(%{aspd: 2000}).derived_stats.aspd == 193
    end

    test "aspd_rate status grants its percent of the distance to 195" do
      base = status_stats(%{}).derived_stats.aspd
      boosted = status_stats(%{aspd_rate: 5}).derived_stats.aspd

      assert boosted == base + div(max(195 - base, 2) * 5, 100)
      assert boosted > base
    end

    test "no aspd_rate status leaves ASPD at the 100 baseline" do
      assert status_stats(%{aspd_rate: 0}).derived_stats.aspd ==
               status_stats(%{}).derived_stats.aspd
    end

    test "aspd_penalty_rate increases attack delay after positive ASPD modifiers" do
      unpenalized = status_stats(%{aspd_rate: 5}).derived_stats.aspd
      penalized = status_stats(%{aspd_rate: 5, aspd_penalty_rate: 250}).derived_stats.aspd

      assert penalized == 200 - div((200 - unpenalized) * 1_250, 1_000)
      assert penalized < unpenalized
    end

    test "no ASPD penalty preserves the calculated ASPD" do
      assert status_stats(%{aspd_rate: 5, aspd_penalty_rate: 0}).derived_stats.aspd ==
               status_stats(%{aspd_rate: 5}).derived_stats.aspd
    end
  end

  describe "passive aspd_bonus, int_bonus, and str_bonus" do
    defp learned_skills_stats(learned_skills) do
      %Stats{
        base_stats: %{str: 10, agi: 30, vit: 25, int: 30, dex: 20, luk: 10},
        progression: %{
          base_level: 50,
          job_level: 25,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: learned_skills
        },
        current_state: %{hp: 1, sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }
      |> Stats.calculate_stats()
    end

    test "a learned aspd_bonus/int_bonus/str_bonus passive reaches derived stats" do
      stub(Catalog, :by_id, fn 9_900_010 -> {:ok, AspdIntPassive.definition()} end)

      stub(Catalog, :passive_module_for, fn :test_aspd_int_passive ->
        {:ok, AspdIntPassive}
      end)

      base = learned_skills_stats(%{})
      boosted = learned_skills_stats(%{9_900_010 => 5})

      # The passive's flat 200 ASPD at level 5 scales by AGI / 200, so the
      # boost lands as exactly the effective AGI.
      agi = Stats.get_effective_stat(base, :agi)

      assert boosted.derived_stats.aspd == min(base.derived_stats.aspd + agi, 193)
      assert boosted.derived_stats.aspd > base.derived_stats.aspd
      assert Stats.get_effective_stat(boosted, :int) == Stats.get_effective_stat(base, :int) + 10
      assert Stats.get_effective_stat(boosted, :str) == Stats.get_effective_stat(base, :str) + 5
      assert boosted.combat_stats.atk > base.combat_stats.atk
    end
  end

  describe "SA_ADVANCEDBOOK weapon gating" do
    defp advancedbook_stats(learned_skills, equipped_items) do
      # AGI 200 makes the AGI / 200 scaling of flat ASPD bonuses exactly 1,
      # so the skill's +3 lands as +3 on the final ASPD.
      %Stats{
        base_stats: %{str: 10, agi: 200, vit: 25, int: 30, dex: 20, luk: 10},
        progression: %{
          base_level: 50,
          job_level: 25,
          base_exp: 0,
          job_exp: 0,
          # Sage (job_id 16): the only class with a `book` entry in its base
          # ASPD table, needed to compute ASPD for a book-wielding combatant.
          job_id: 16,
          learned_skills: learned_skills
        },
        current_state: %{hp: 1, sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }
      |> Stats.calculate_stats(nil, equipped_items)
    end

    test "atk_bonus and aspd_bonus apply only with a book, tested both ways" do
      book = %ItemDefinition{
        id: 92_001,
        aegis_name: "test_book",
        name: "Test Book",
        type: :weapon,
        subtype: :book,
        weapon_level: 1
      }

      stub(ItemManagement, :get_item_by_id, fn 92_001 -> {:ok, book} end)

      learned = %{274 => 5}

      fist_no_skill = advancedbook_stats(%{}, [])
      fist_with_skill = advancedbook_stats(learned, [])
      book_no_skill = advancedbook_stats(%{}, [equipped(92_001, @right_hand)])
      book_with_skill = advancedbook_stats(learned, [equipped(92_001, @right_hand)])

      assert fist_with_skill.combat_stats.atk == fist_no_skill.combat_stats.atk
      assert fist_with_skill.derived_stats.aspd == fist_no_skill.derived_stats.aspd

      assert book_with_skill.combat_stats.atk == book_no_skill.combat_stats.atk + 15

      assert book_with_skill.derived_stats.aspd ==
               min(book_no_skill.derived_stats.aspd + 3, 193)
    end
  end

  describe "SA_DRAGONOLOGY int_bonus" do
    defp dragonology_stats(learned_skills) do
      %Stats{
        base_stats: %{str: 10, agi: 30, vit: 25, int: 30, dex: 20, luk: 10},
        progression: %{
          base_level: 50,
          job_level: 25,
          base_exp: 0,
          job_exp: 0,
          job_id: 0,
          learned_skills: learned_skills
        },
        current_state: %{hp: 1, sp: 1},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }
      |> Stats.calculate_stats()
    end

    test "raises effective INT by (level + 1) / 2, levels 1 and 5" do
      base = dragonology_stats(%{})
      lv1 = dragonology_stats(%{284 => 1})
      lv5 = dragonology_stats(%{284 => 5})

      assert Stats.get_effective_stat(lv1, :int) == Stats.get_effective_stat(base, :int) + 1
      assert Stats.get_effective_stat(lv5, :int) == Stats.get_effective_stat(base, :int) + 3
    end
  end

  describe "status max HP/SP rate modifiers" do
    test "max_hp_rate/max_sp_rate scale the computed max" do
      base = status_stats(%{})
      boosted = status_stats(%{max_hp_rate: 50, max_sp_rate: 50})

      assert boosted.derived_stats.max_hp == trunc(base.derived_stats.max_hp * 150 / 100)
      assert boosted.derived_stats.max_sp == trunc(base.derived_stats.max_sp * 150 / 100)
    end

    test "max HP/SP floor at 1 for an extreme negative rate" do
      reduced = status_stats(%{max_hp_rate: -100, max_sp_rate: -100})

      assert reduced.derived_stats.max_hp == 1
      assert reduced.derived_stats.max_sp == 1
    end

    test "negative rate clamps current HP/SP to the reduced max" do
      base = status_stats(%{})
      full = %{hp: base.derived_stats.max_hp, sp: base.derived_stats.max_sp}
      reduced = status_stats(%{max_hp_rate: -50, max_sp_rate: -50}, full)

      assert reduced.current_state.hp == reduced.derived_stats.max_hp
      assert reduced.current_state.sp == reduced.derived_stats.max_sp
      assert reduced.current_state.hp < base.derived_stats.max_hp
    end

    test "a non-negative rate leaves current HP/SP untouched even above the max" do
      over = status_stats(%{max_hp_rate: 10}, %{hp: 99_999, sp: 99_999})

      assert over.current_state.hp == 99_999
      assert over.current_state.sp == 99_999
    end
  end
end
