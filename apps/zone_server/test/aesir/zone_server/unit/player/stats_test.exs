defmodule Aesir.ZoneServer.Unit.Player.StatsTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :setup_ets_tables

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
        progression: %{base_level: 40, job_level: 20, base_exp: 500, job_exp: 200, job_id: 0},
        current_state: %{hp: 600, sp: 250},
        equipment: %{weapon: 0, shield: 0},
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
        progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        current_state: %{hp: 1, sp: 1},
        equipment: %{weapon: 0, shield: 0},
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
        equipment: %{weapon: 0, shield: 0}
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
        equipment: %{weapon: 0, shield: 0}
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

    test "handles missing modifiers gracefully" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 15, vit: 20, int: 25, dex: 12, luk: 8},
        modifiers: %{
          equipment: %{str: 5},
          status_effects: %{},
          job_bonuses: %{int: 3}
        },
        equipment: %{weapon: 0, shield: 0}
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
        progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        equipment: %{weapon: 0, shield: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 1: JobData.get_base_hp(0, 1) = 40, with VIT=1: 40 * (1.0 + 1*0.01) = 40.4 -> 40
      assert updated_stats.derived_stats.max_hp == 40
    end

    test "calculates HP correctly for higher level character" do
      stats = %Stats{
        base_stats: %{vit: 50, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{base_level: 75, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        equipment: %{weapon: 0, shield: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 75: JobData.get_base_hp(0, 75) = 410, with VIT=50: 410 * (1.0 + 50*0.01) = 410 * 1.5 = 615
      assert updated_stats.derived_stats.max_hp == 615
    end

    test "calculates HP correctly for max novice level" do
      stats = %Stats{
        base_stats: %{vit: 99, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{base_level: 99, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        equipment: %{weapon: 0, shield: 0},
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
        progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        equipment: %{weapon: 0, shield: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 1: JobData.get_base_sp(0, 1) = 11, with INT=1: 11 * (1.0 + 1*0.01) = 11.11 -> 11
      assert updated_stats.derived_stats.max_sp == 11
    end

    test "calculates SP correctly for higher level character" do
      stats = %Stats{
        base_stats: %{int: 80, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{base_level: 60, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        equipment: %{weapon: 0, shield: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 60: JobData.get_base_sp(0, 60) = 70, with INT=80: 70 * (1.0 + 80*0.01) = 70 * 1.8 = 126
      assert updated_stats.derived_stats.max_sp == 126
    end

    test "calculates SP correctly for max novice level" do
      stats = %Stats{
        base_stats: %{int: 99, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{base_level: 99, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        equipment: %{weapon: 0, shield: 0},
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
        progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0, job_id: 0},
        equipment: %{weapon: 0, shield: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.apply_job_bonuses(stats)
      assert result.modifiers.job_bonuses == %{}
    end

    test "equipment modifiers remain unchanged (placeholder)" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        equipment: %{weapon: 0, shield: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      result = Stats.apply_equipment_modifiers(stats)
      assert result == stats
    end

    test "status effects remain unchanged (placeholder)" do
      stats = %Stats{
        base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        equipment: %{weapon: 0, shield: 0},
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
        progression: %{base_level: 0},
        equipment: %{weapon: 0, shield: 0},
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
        progression: %{base_level: 0},
        equipment: %{weapon: 0, shield: 0},
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
  end
end
