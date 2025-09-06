defmodule Aesir.ZoneServer.Mmo.Combat.DamageCalculatorTest do
  @moduledoc """
  Tests for the unified damage calculation system.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    # Copy modules for stubbing
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(RaceModifiers)
    Mimic.copy(CriticalHits)
    Mimic.copy(ModifierCalculator)
    :ok
  end

  describe "calculate_damage/2" do
    test "calculates basic player vs mob damage" do
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      {attacker, defender} = CombatTestHelper.create_combat_scenario()

      assert {:ok, result} = DamageCalculator.calculate_damage(attacker, defender)
      assert is_integer(result.damage)
      assert result.damage > 0
      assert is_boolean(result.is_critical)
    end

    test "calculates mob vs player damage" do
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      mob = CombatTestHelper.create_mob_combatant()
      player = CombatTestHelper.create_player_combatant()

      assert {:ok, result} = DamageCalculator.calculate_damage(mob, player)
      assert is_integer(result.damage)
      assert result.damage > 0
      assert is_boolean(result.is_critical)
    end

    test "handles critical hits" do
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage * 2, is_critical: true}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      {attacker, defender} = CombatTestHelper.create_combat_scenario()

      assert {:ok, result} = DamageCalculator.calculate_damage(attacker, defender)
      assert result.is_critical == true
      assert result.damage > 0
    end

    test "applies element modifiers" do
      stub(ElementModifiers, :get_modifier, fn
        # Fire strong vs Earth
        :fire, :earth, _ -> 1.5
        # Default neutral modifier
        _, _, _ -> 1.0
      end)

      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      # Fire weapon vs Earth element mob
      attacker = CombatTestHelper.create_player_combatant(weapon_element: :fire)
      defender = CombatTestHelper.create_mob_combatant(element: {:earth, 1})

      # Calculate damage with neutral weapon for comparison
      neutral_attacker = CombatTestHelper.create_player_combatant(weapon_element: :neutral)

      assert {:ok, fire_result} = DamageCalculator.calculate_damage(attacker, defender)
      assert {:ok, neutral_result} = DamageCalculator.calculate_damage(neutral_attacker, defender)

      # Fire weapon should do more damage than neutral against Earth
      assert fire_result.damage >= neutral_result.damage
    end

    test "applies size modifiers" do
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      # All size weapons vs Large
      stub(SizeModifiers, :get_modifier, fn :all, :large -> 1.25 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      attacker = CombatTestHelper.create_player_combatant(weapon_size: :all)
      defender = CombatTestHelper.create_mob_combatant(size: :large)

      assert {:ok, result} = DamageCalculator.calculate_damage(attacker, defender)
      assert result.damage > 0
    end

    test "returns error for unknown unit type" do
      unknown_attacker = CombatTestHelper.create_player_combatant()
      unknown_attacker = %{unknown_attacker | unit_type: :unknown}
      defender = CombatTestHelper.create_mob_combatant()

      assert {:error, :unknown_unit_type} =
               DamageCalculator.calculate_damage(unknown_attacker, defender)
    end
  end

  describe "calculate_base_attack/1" do
    test "calculates player base attack correctly" do
      player =
        CombatTestHelper.create_player_combatant(
          str: 20,
          dex: 15,
          luk: 10,
          base_level: 20
        )

      assert {:ok, base_atk} = DamageCalculator.calculate_base_attack(player)

      # Player formula: (STR * 2) + (DEX / 5) + (LUK / 3) + base_level/4 + weapon_atk
      expected_stat_portion = 20 * 2 + div(15, 5) + div(10, 3) + div(20, 4)
      # Should be at least stat portion + weapon attack
      assert base_atk >= expected_stat_portion
    end

    test "calculates mob base attack with variance" do
      mob = CombatTestHelper.create_mob_combatant(atk: 100)

      # Run multiple times to test variance
      results =
        for _ <- 1..10 do
          {:ok, atk} = DamageCalculator.calculate_base_attack(mob)
          atk
        end

      # All results should be around 100 ± 25% variance
      assert Enum.all?(results, fn atk -> atk >= 75 and atk <= 125 end)

      # Should have some variance (not all the same)
      unique_results = Enum.uniq(results)
      assert length(unique_results) > 1
    end

    test "returns error for unknown unit type" do
      unknown = CombatTestHelper.create_player_combatant()
      unknown = %{unknown | unit_type: :unknown}

      assert {:error, :unknown_unit_type} = DamageCalculator.calculate_base_attack(unknown)
    end
  end

  describe "apply_modifier_pipeline/3" do
    test "applies all modifiers in sequence" do
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.1 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.2 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.5 end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ ->
        %{damage_bonus: 10, damage_multiplier: 0.1}
      end)

      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert {:ok, result} = DamageCalculator.apply_modifier_pipeline(100, attacker, defender)

      # Should apply size (1.1) * race (1.2) * element (1.5) + damage bonus (10) * multiplier (1.1)
      # = 100 * 1.1 * 1.2 * 1.5 = 198, then (198 + 10) * 1.1 = 228.8
      # Should be significantly higher than base
      assert result > 100
    end

    test "handles no modifiers gracefully" do
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert {:ok, result} = DamageCalculator.apply_modifier_pipeline(100, attacker, defender)
      # No modifiers = no change
      assert result == 100
    end
  end

  describe "apply_defense_formula/2" do
    test "applies renewal defense formula to player" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      # Soft defense
      player = CombatTestHelper.create_player_combatant(vit: 20)
      # Hard defense
      player = %{player | combat_stats: %{player.combat_stats | def: 10}}

      assert {:ok, final_damage} = DamageCalculator.apply_defense_formula(200, player)

      # Should apply Renewal formula: Attack * (4000 + eDEF) / (4000 + eDEF*10) - sDEF
      # Expected: 200 * (4000 + 10) / (4000 + 100) - 20
      # = 200 * 4010 / 4100 - 20 = ~195.85 - 20 = ~176
      assert final_damage > 0
      # Should be less than original attack due to defense
      assert final_damage < 200
    end

    test "applies renewal defense formula to mob" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      mob = CombatTestHelper.create_mob_combatant(def: 15)

      assert {:ok, final_damage} = DamageCalculator.apply_defense_formula(150, mob)

      # Mobs have no soft defense in our implementation
      # Expected: 150 * (4000 + 15) / (4000 + 150) - 0
      assert final_damage > 0
      assert final_damage < 150
    end

    test "ensures minimum damage of 1" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      # Very high defense vs very low attack
      high_def_player = CombatTestHelper.create_player_combatant(vit: 100)

      high_def_player = %{
        high_def_player
        | combat_stats: %{high_def_player.combat_stats | def: 500}
      }

      assert {:ok, final_damage} = DamageCalculator.apply_defense_formula(10, high_def_player)
      # Should never be less than 1
      assert final_damage >= 1
    end

    test "handles edge case of hard_def = -400" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{def_bonus: -500} end)

      player = CombatTestHelper.create_player_combatant()
      player = %{player | combat_stats: %{player.combat_stats | def: 100}}

      # Status effect reduces def by 500, making it -400
      assert {:ok, final_damage} = DamageCalculator.apply_defense_formula(100, player)
      # Should handle division by zero case
      assert final_damage > 0
    end

    test "applies status effect defense modifiers" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ ->
        %{def_bonus: 50, vit_bonus: 10, defense_multiplier: 0.2}
      end)

      player = CombatTestHelper.create_player_combatant(vit: 20)
      player = %{player | combat_stats: %{player.combat_stats | def: 10}}

      assert {:ok, final_damage} = DamageCalculator.apply_defense_formula(200, player)

      # Should apply status effect bonuses:
      # hard_def = (10 + 50) * 1.2 = 72
      # soft_def = (20 + 10) * 1.2 = 36
      assert final_damage > 0
    end
  end

  describe "apply_critical_hit/2" do
    test "applies critical hit multiplier" do
      stub(CriticalHits, :calculate_critical_hit, fn %{luk: _}, damage ->
        %{damage: damage * 2, is_critical: true}
      end)

      attacker = CombatTestHelper.create_player_combatant(luk: 30)

      assert {:ok, result} = DamageCalculator.apply_critical_hit(100, attacker)
      assert result.damage == 200
      assert result.is_critical == true
    end

    test "handles non-critical hits" do
      stub(CriticalHits, :calculate_critical_hit, fn %{luk: _}, damage ->
        %{damage: damage, is_critical: false}
      end)

      attacker = CombatTestHelper.create_player_combatant(luk: 5)

      assert {:ok, result} = DamageCalculator.apply_critical_hit(100, attacker)
      assert result.damage == 100
      assert result.is_critical == false
    end
  end

  describe "integration scenarios" do
    test "high level vs low level combat" do
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      high_level = CombatTestHelper.create_high_level_player()
      low_level_mob = CombatTestHelper.create_mob_combatant(base_level: 1, def: 1)

      assert {:ok, result} = DamageCalculator.calculate_damage(high_level, low_level_mob)
      # Should do significant damage
      assert result.damage > 50
    end

    test "boss fight scenario" do
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      player = CombatTestHelper.create_high_level_player()
      boss = CombatTestHelper.create_boss_mob()

      # Player attacks boss
      assert {:ok, player_result} = DamageCalculator.calculate_damage(player, boss)

      # Boss attacks player
      assert {:ok, boss_result} = DamageCalculator.calculate_damage(boss, player)

      # Both should do reasonable damage
      assert player_result.damage > 0
      assert boss_result.damage > 0
    end

    test "ranged combat scenario" do
      stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(SizeModifiers, :player_size, fn -> :medium end)
      stub(RaceModifiers, :get_modifier, fn _, _ -> 1.0 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      {archer, target} = CombatTestHelper.create_ranged_scenario()

      assert {:ok, result} = DamageCalculator.calculate_damage(archer, target)
      assert result.damage > 0
      # Ranged weapons might have different damage characteristics
    end
  end
end
