defmodule Aesir.ZoneServer.Unit.Player.StatsTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Player.Stats

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
        sp: 300
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
    end

    test "initializes empty modifiers" do
      character = %Character{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1}
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
        progression: %{base_level: 40, job_level: 20, base_exp: 500, job_exp: 200},
        current_state: %{hp: 600, sp: 250}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Should calculate HP based on VIT and level
      # base + level * 5
      expected_base_hp = 35 + 40 * 5
      expected_max_hp = trunc(expected_base_hp * (1.0 + 25 * 0.01))
      assert updated_stats.derived_stats.max_hp == expected_max_hp

      # Should calculate SP based on INT and level
      # base + level * 2
      expected_base_sp = 10 + 40 * 2
      expected_max_sp = trunc(expected_base_sp * (1.0 + 30 * 0.01))
      assert updated_stats.derived_stats.max_sp == expected_max_sp
    end

    test "ensures minimum HP/SP values" do
      stats = %Stats{
        base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0},
        current_state: %{hp: 1, sp: 1}
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
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
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
        }
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
        }
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
        progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 1: base_hp = 35 + 1*5 = 40, with VIT=1: 40 * (1.0 + 1*0.01) = 40.4 -> 40
      assert updated_stats.derived_stats.max_hp == 40
    end

    test "calculates HP correctly for higher level character" do
      stats = %Stats{
        base_stats: %{vit: 50, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{base_level: 75, job_level: 1, base_exp: 0, job_exp: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 75: base_hp = 35 + 75*5 = 410, with VIT=50: 410 * (1.0 + 50*0.01) = 410 * 1.5 = 615
      assert updated_stats.derived_stats.max_hp == 615
    end

    test "calculates HP correctly for transcendent levels" do
      stats = %Stats{
        base_stats: %{vit: 99, str: 1, agi: 1, int: 1, dex: 1, luk: 1},
        progression: %{base_level: 150, job_level: 1, base_exp: 0, job_exp: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 150: base_hp = 535 + (150-99)*10 = 535 + 510 = 1045, with VIT=99: 1045 * (1.0 + 99*0.01) = 1045 * 1.99 = 2079.55 -> 2079
      assert updated_stats.derived_stats.max_hp == 2079
    end
  end

  describe "rAthena SP formula accuracy" do
    test "calculates SP correctly for level 1 character" do
      stats = %Stats{
        base_stats: %{int: 1, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{base_level: 1, job_level: 1, base_exp: 0, job_exp: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 1: base_sp = 10 + 1*2 = 12, with INT=1: 12 * (1.0 + 1*0.01) = 12.12 -> 12
      assert updated_stats.derived_stats.max_sp == 12
    end

    test "calculates SP correctly for higher level character" do
      stats = %Stats{
        base_stats: %{int: 80, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{base_level: 60, job_level: 1, base_exp: 0, job_exp: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 60: base_sp = 10 + 60*2 = 130, with INT=80: 130 * (1.0 + 80*0.01) = 130 * 1.8 = 234
      assert updated_stats.derived_stats.max_sp == 234
    end

    test "calculates SP correctly for transcendent levels" do
      stats = %Stats{
        base_stats: %{int: 120, str: 1, agi: 1, vit: 1, dex: 1, luk: 1},
        progression: %{base_level: 175, job_level: 1, base_exp: 0, job_exp: 0},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
      }

      updated_stats = Stats.calculate_stats(stats)

      # Level 175: base_sp = 208 + (175-99)*3 = 208 + 228 = 436, with INT=120: 436 * (1.0 + 120*0.01) = 436 * 2.2 = 959.2 -> 959
      assert updated_stats.derived_stats.max_sp == 959
    end
  end

  describe "modifier system" do
    test "job bonuses remain unchanged (placeholder)" do
      stats = %Stats{base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}}
      result = Stats.apply_job_bonuses(stats)
      assert result == stats
    end

    test "equipment modifiers remain unchanged (placeholder)" do
      stats = %Stats{base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}}
      result = Stats.apply_equipment_modifiers(stats)
      assert result == stats
    end

    test "status effects remain unchanged (placeholder)" do
      stats = %Stats{base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}}
      result = Stats.apply_status_effects(stats)
      assert result == stats
    end
  end

  describe "combat stats calculation" do
    test "initializes combat stats to zero (placeholder)" do
      stats = %Stats{}
      result = Stats.calculate_combat_stats(stats)

      assert result.combat_stats.hit == 0
      assert result.combat_stats.flee == 0
      assert result.combat_stats.critical == 0
      assert result.combat_stats.atk == 0
      assert result.combat_stats.def == 0
    end
  end
end
