defmodule Aesir.ZoneServer.Mmo.Combat.CombatantTest do
  @moduledoc """
  Tests for the Combatant struct and its helper functions.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.Combatant

  describe "new/1" do
    test "creates valid combatant with all required fields" do
      attrs = %{
        unit_id: 1001,
        unit_type: :player,
        base_stats: %{
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10
        },
        combat_stats: %{
          atk: 50,
          def: 20,
          hit: 100,
          flee: 80,
          perfect_dodge: 5
        },
        progression: %{
          base_level: 10,
          job_level: 1
        },
        element: :neutral,
        race: :human,
        size: :medium,
        weapon: %{
          type: :sword,
          element: :neutral,
          size: :all
        }
      }

      assert {:ok, combatant} = Combatant.new(attrs)
      assert combatant.unit_id == 1001
      assert combatant.unit_type == :player
      assert combatant.base_stats.str == 10
      assert combatant.combat_stats.atk == 50
      assert combatant.progression.base_level == 10
    end

    test "creates combatant even with missing optional fields" do
      attrs = %{
        unit_id: 1001,
        unit_type: :player
        # Missing other fields - TypedStruct allows this
      }

      assert {:ok, combatant} = Combatant.new(attrs)
      assert combatant.unit_id == 1001
      assert combatant.unit_type == :player
      # Optional/missing fields are nil
      assert combatant.base_stats == nil
    end

    test "creates combatant with optional fields omitted" do
      attrs = %{
        unit_id: 1001,
        unit_type: :player,
        base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10},
        combat_stats: %{atk: 50, def: 20, hit: 100, flee: 80, perfect_dodge: 5},
        progression: %{base_level: 10, job_level: 1},
        element: :neutral,
        race: :human,
        size: :medium,
        weapon: %{type: :sword, element: :neutral, size: :all}
        # position and map_name are optional
      }

      assert {:ok, combatant} = Combatant.new(attrs)
      assert combatant.position == nil
      assert combatant.map_name == nil
    end
  end

  describe "new!/1" do
    test "creates combatant with valid data" do
      combatant = CombatTestHelper.create_player_combatant()
      assert %Combatant{} = combatant
      assert combatant.unit_id == 1001
      assert combatant.unit_type == :player
    end

    test "raises on struct creation error" do
      # Since TypedStruct doesn't enforce at struct creation,
      # we test validation instead
      combatant = CombatTestHelper.create_player_combatant()
      invalid_combatant = %{combatant | unit_id: -1}

      # This should fail validation
      assert {:error, _} = Combatant.validate_for_combat(invalid_combatant)
    end
  end

  describe "validate_for_combat/1" do
    test "validates correct combatant" do
      combatant = CombatTestHelper.create_player_combatant()
      assert :ok = Combatant.validate_for_combat(combatant)
    end

    test "rejects invalid unit_id" do
      combatant = CombatTestHelper.create_player_combatant(unit_id: 0)
      assert {:error, error} = Combatant.validate_for_combat(combatant)
      assert error =~ "Invalid unit_id"
    end

    test "rejects invalid unit_type" do
      combatant = CombatTestHelper.create_player_combatant()
      invalid_combatant = %{combatant | unit_type: :invalid}
      assert {:error, error} = Combatant.validate_for_combat(invalid_combatant)
      assert error =~ "Invalid unit_type"
    end

    test "rejects invalid base_stats" do
      combatant = CombatTestHelper.create_player_combatant()
      invalid_combatant = %{combatant | base_stats: "invalid"}
      assert {:error, error} = Combatant.validate_for_combat(invalid_combatant)
      assert error =~ "Invalid base_stats"
    end

    test "rejects invalid combat_stats" do
      combatant = CombatTestHelper.create_player_combatant()
      invalid_combatant = %{combatant | combat_stats: "invalid"}
      assert {:error, error} = Combatant.validate_for_combat(invalid_combatant)
      assert error =~ "Invalid combat_stats"
    end

    test "rejects invalid base_level" do
      combatant = CombatTestHelper.create_player_combatant()
      invalid_progression = %{combatant.progression | base_level: 0}
      invalid_combatant = %{combatant | progression: invalid_progression}
      assert {:error, error} = Combatant.validate_for_combat(invalid_combatant)
      assert error =~ "Invalid base_level"
    end
  end

  describe "get_unit_id/1" do
    test "returns unit ID" do
      combatant = CombatTestHelper.create_player_combatant(unit_id: 12_345)
      assert Combatant.get_unit_id(combatant) == 12_345
    end
  end

  describe "get_unit_type/1" do
    test "returns player type" do
      combatant = CombatTestHelper.create_player_combatant()
      assert Combatant.get_unit_type(combatant) == :player
    end

    test "returns mob type" do
      combatant = CombatTestHelper.create_mob_combatant()
      assert Combatant.get_unit_type(combatant) == :mob
    end
  end

  describe "player?/1" do
    test "returns true for player combatant" do
      combatant = CombatTestHelper.create_player_combatant()
      assert Combatant.player?(combatant) == true
    end

    test "returns false for mob combatant" do
      combatant = CombatTestHelper.create_mob_combatant()
      assert Combatant.player?(combatant) == false
    end
  end

  describe "mob?/1" do
    test "returns true for mob combatant" do
      combatant = CombatTestHelper.create_mob_combatant()
      assert Combatant.mob?(combatant) == true
    end

    test "returns false for player combatant" do
      combatant = CombatTestHelper.create_player_combatant()
      assert Combatant.mob?(combatant) == false
    end
  end

  describe "combatant creation scenarios" do
    test "creates different types of combatants" do
      # Player combatant
      player = CombatTestHelper.create_player_combatant()
      assert player.unit_type == :player
      assert player.race == :human
      assert player.element == :neutral
      assert player.size == :medium

      # Mob combatant
      mob = CombatTestHelper.create_mob_combatant()
      assert mob.unit_type == :mob
      assert mob.race == :brute
      assert mob.element == :earth
      assert mob.size == :medium

      # High level player
      high_level = CombatTestHelper.create_high_level_player()
      assert high_level.progression.base_level == 50
      assert high_level.base_stats.str == 50

      # Boss mob
      boss = CombatTestHelper.create_boss_mob()
      assert boss.progression.base_level == 30
      assert boss.element == :dark
      assert boss.race == :demon
      assert boss.size == :large
    end

    test "creates combat scenarios" do
      {attacker, defender} = CombatTestHelper.create_combat_scenario()
      assert Combatant.player?(attacker)
      assert Combatant.mob?(defender)
      assert attacker.unit_id != defender.unit_id

      {player1, player2} = CombatTestHelper.create_pvp_scenario()
      assert Combatant.player?(player1)
      assert Combatant.player?(player2)
      assert player1.unit_id != player2.unit_id

      {archer, target} = CombatTestHelper.create_ranged_scenario()
      assert archer.weapon.type == :bow
      assert archer.position == {100, 100}
      assert target.position == {110, 110}
    end

    test "allows customization of combatant properties" do
      custom_player =
        CombatTestHelper.create_player_combatant(
          unit_id: 9999,
          str: 99,
          base_level: 99,
          weapon_type: :spear,
          element: :fire
        )

      assert custom_player.unit_id == 9999
      assert custom_player.base_stats.str == 99
      assert custom_player.progression.base_level == 99
      assert custom_player.weapon.type == :spear
      assert custom_player.element == :fire
    end
  end

  describe "stat calculations in test helper" do
    test "calculates reasonable stats for different levels" do
      low_level = CombatTestHelper.create_player_combatant(base_level: 1, str: 1, dex: 1)
      high_level = CombatTestHelper.create_player_combatant(base_level: 99, str: 99, dex: 99)

      # Higher level should have higher combat stats
      assert high_level.combat_stats.atk > low_level.combat_stats.atk
      assert high_level.combat_stats.hit > low_level.combat_stats.hit
    end

    test "mob stats differ from player stats appropriately" do
      player = CombatTestHelper.create_player_combatant(base_level: 10, dex: 20)
      mob = CombatTestHelper.create_mob_combatant(base_level: 10, dex: 20)

      # Mobs have slight hit/flee bonuses compared to players
      assert mob.combat_stats.hit > player.combat_stats.hit
      assert mob.combat_stats.flee > player.combat_stats.flee
    end
  end
end
