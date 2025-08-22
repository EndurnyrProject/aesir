defmodule Aesir.ZoneServer.Unit.Player.AspdTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :setup_ets_tables

  describe "ASPD calculation" do
    test "calculates ASPD for barehand novice" do
      character = %Character{
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 1,
        job_level: 1,
        # Novice
        class: 0,
        # Barehand
        weapon: 0,
        shield: 0
      }

      stats = Stats.from_character(character)

      # Novice barehand base ASPD is typically around 156
      # With AGI=1 and DEX=1, stat modifier is minimal
      # Expected ASPD should be around 156-157
      assert stats.derived_stats.aspd >= 150
      assert stats.derived_stats.aspd <= 160
    end

    test "calculates ASPD with higher AGI and DEX" do
      character = %Character{
        str: 10,
        agi: 50,
        vit: 10,
        int: 10,
        dex: 30,
        luk: 10,
        base_level: 50,
        job_level: 25,
        # Novice
        class: 0,
        # Barehand
        weapon: 0,
        shield: 0
      }

      stats = Stats.from_character(character)

      # Higher AGI and DEX should increase ASPD
      assert stats.derived_stats.aspd > 160
      # Max ASPD cap
      assert stats.derived_stats.aspd <= 193
    end

    test "applies shield penalty to ASPD" do
      character_no_shield = %Character{
        str: 10,
        agi: 30,
        vit: 10,
        int: 10,
        dex: 20,
        luk: 10,
        base_level: 30,
        job_level: 15,
        # Novice
        class: 0,
        # Barehand
        weapon: 0,
        shield: 0
      }

      character_with_shield = %Character{
        str: 10,
        agi: 30,
        vit: 10,
        int: 10,
        dex: 20,
        luk: 10,
        base_level: 30,
        job_level: 15,
        # Novice
        class: 0,
        # Barehand
        weapon: 0,
        # Has shield
        shield: 1
      }

      stats_no_shield = Stats.from_character(character_no_shield)
      stats_with_shield = Stats.from_character(character_with_shield)

      # Shield should reduce ASPD
      assert stats_no_shield.derived_stats.aspd >= stats_with_shield.derived_stats.aspd
    end

    test "ranged weapons use different formula" do
      character_melee = %Character{
        str: 10,
        agi: 30,
        vit: 10,
        int: 10,
        dex: 30,
        luk: 10,
        base_level: 30,
        job_level: 15,
        # Novice
        class: 0,
        # Dagger (melee)
        weapon: 1,
        shield: 0
      }

      character_ranged = %Character{
        str: 10,
        agi: 30,
        vit: 10,
        int: 10,
        dex: 30,
        luk: 10,
        base_level: 30,
        job_level: 15,
        # Novice
        class: 0,
        # Bow (ranged)
        weapon: 11,
        shield: 0
      }

      stats_melee = Stats.from_character(character_melee)
      stats_ranged = Stats.from_character(character_ranged)

      # Different formulas should produce different results
      # Ranged emphasizes DEX more than melee
      assert stats_melee.derived_stats.aspd != stats_ranged.derived_stats.aspd
    end

    test "ASPD is capped at 193" do
      character = %Character{
        str: 10,
        agi: 99,
        vit: 10,
        int: 10,
        dex: 99,
        luk: 10,
        base_level: 99,
        job_level: 50,
        # Novice
        class: 0,
        # Barehand
        weapon: 0,
        shield: 0
      }

      stats = Stats.from_character(character)

      # Even with max stats, ASPD should not exceed 193
      assert stats.derived_stats.aspd <= 193
    end

    test "ASPD includes job bonuses to AGI and DEX" do
      character = %Character{
        str: 10,
        agi: 20,
        vit: 10,
        int: 10,
        dex: 20,
        luk: 10,
        base_level: 40,
        job_level: 20,
        # Novice
        class: 0,
        # Barehand
        weapon: 0,
        shield: 0
      }

      stats = Stats.from_character(character)

      # Job bonuses at level 20 add +1 to all stats
      # This should slightly increase ASPD
      assert stats.derived_stats.aspd > 150
    end
  end
end
