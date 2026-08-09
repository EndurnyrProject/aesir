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
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @element_status_keys [
    water: :subele_water,
    earth: :subele_earth,
    fire: :subele_fire,
    wind: :subele_wind
  ]

  @weapon_types [
    :fist,
    :dagger,
    :one_handed_sword,
    :two_handed_sword,
    :one_handed_spear,
    :two_handed_spear,
    :one_handed_axe,
    :two_handed_axe,
    :mace,
    :two_handed_mace,
    :staff,
    :two_handed_staff,
    :bow,
    :musical,
    :whip,
    :book,
    :katar,
    :knuckle,
    :revolver,
    :rifle,
    :gatling,
    :shotgun,
    :grenade,
    :huuma
  ]

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
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
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
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
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
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
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

    test "CRate reaches the crit path: a player with crate>0 crits harder (real CriticalHits)" do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      defender = CombatTestHelper.create_mob_combatant()

      # LUK 300 -> crit rate capped at 1000/1000, so both attackers always crit
      # regardless of the RNG seed, isolating the crate factor (1.4 vs 1.4+0.01*50).
      base = CombatTestHelper.create_player_combatant(luk: 300, str: 60, base_level: 90)
      no_crate = %{base | combat_stats: Map.put(base.combat_stats, :crate, 0)}
      high_crate = %{base | combat_stats: Map.put(base.combat_stats, :crate, 50)}

      :rand.seed(:exsss, {7, 8, 9})
      {:ok, low} = DamageCalculator.calculate_damage(no_crate, defender)

      :rand.seed(:exsss, {7, 8, 9})
      {:ok, high} = DamageCalculator.calculate_damage(high_crate, defender)

      assert low.is_critical
      assert high.is_critical
      assert high.damage > low.damage
    end

    test "applies element modifiers" do
      stub(ElementModifiers, :get_modifier, fn
        # Fire strong vs Earth
        :fire, :earth, _, _ -> 1.5
        # Default neutral modifier
        _, _, _, _ -> 1.0
      end)

      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
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
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      # All size weapons vs Large
      stub(SizeModifiers, :get_modifier, fn :fist, :large, false -> 125 end)
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

  describe "calculate_damage/2 attack element resolution" do
    setup do
      stub(ElementModifiers, :get_modifier, fn attack_element, _, _, _ ->
        send(self(), {:attack_element, attack_element})
        1.0
      end)

      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      :ok
    end

    test "sc_watk_element overrides the weapon element when present" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{attack_element: :fire}
        _, _ -> %{}
      end)

      attacker = CombatTestHelper.create_player_combatant(weapon_element: :neutral)
      defender = CombatTestHelper.create_mob_combatant(element: {:earth, 1})

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender)
      assert_received {:attack_element, :fire}
    end

    test "sc_watk_element beats the arrow weapon.element when both are set" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{attack_element: :water}
        _, _ -> %{}
      end)

      attacker = CombatTestHelper.create_player_combatant(weapon_element: :fire)
      defender = CombatTestHelper.create_mob_combatant(element: {:earth, 1})

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender)
      assert_received {:attack_element, :water}
    end

    test "falls back to the weapon element when no attack_element modifier" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      attacker = CombatTestHelper.create_player_combatant(weapon_element: :water)
      defender = CombatTestHelper.create_mob_combatant(element: {:earth, 1})

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender)
      assert_received {:attack_element, :water}
    end

    test "an :element opt overrides both the weapon element and sc_watk_element" do
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{attack_element: :water}
        _, _ -> %{}
      end)

      attacker = CombatTestHelper.create_player_combatant(weapon_element: :fire)
      defender = CombatTestHelper.create_mob_combatant(element: {:earth, 1})

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender, element: :poison)
      assert_received {:attack_element, :poison}
    end
  end

  describe "calculate_base_attack/2 base damage override" do
    test "replaces only the rolled base attack" do
      attacker = CombatTestHelper.create_mob_combatant(atk: 999, str: 99, base_level: 99)

      assert {:ok, 400} = DamageCalculator.calculate_base_attack(attacker, base_damage: 400)
    end

    test "Fleet's Homunculus atk_rate changes the normal base-damage pipeline" do
      stub(ElementModifiers, :get_modifier, fn :fire, :neutral, 1, _bonuses -> 1.5 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      homunculus_id = 30_001

      on_exit(fn ->
        StatusStorage.clear_unit_statuses(:homunculus, homunculus_id)
        UnitRegistry.unregister_unit(:homunculus, homunculus_id)
      end)

      UnitRegistry.register_unit(
        :homunculus,
        homunculus_id,
        HomunculusState,
        %HomunculusState{
          id: 30_001,
          owner_character_id: 30_002,
          class_id: 6003,
          name: "Fleet test",
          world_gid: homunculus_id
        },
        self()
      )

      attacker =
        CombatTestHelper.create_mob_combatant(atk: 999, str: 99, base_level: 99)
        |> Map.put(:unit_type, :homunculus)
        |> Map.put(:unit_id, homunculus_id)

      defender =
        CombatTestHelper.create_player_combatant(vit: 40, base_level: 10)
        |> Map.put(:element, {:neutral, 1})

      opts = [base_damage: 400, skill_ratio: 200, element: :fire, skip_crit: true]

      assert {:ok, %{damage: 800, is_critical: false}} =
               DamageCalculator.calculate_damage(attacker, defender, opts)

      :ok = StatusStorage.apply_status(:homunculus, homunculus_id, :sc_fleet, val2: 0, val3: 25)
      assert %{atk_rate: 25} = ModifierCalculator.get_all_modifiers(:homunculus, homunculus_id)

      assert {:ok, %{damage: 1_010, is_critical: false}} =
               DamageCalculator.calculate_damage(attacker, defender, opts)
    end

    test "rejects negative and non-integer overrides" do
      attacker = CombatTestHelper.create_mob_combatant()

      assert {:error, :invalid_base_damage} =
               DamageCalculator.calculate_base_attack(attacker, base_damage: -1)

      assert {:error, :invalid_base_damage} =
               DamageCalculator.calculate_base_attack(attacker, base_damage: 1.5)
    end

    test "ordinary base attacks remain unit-specific" do
      attacker = CombatTestHelper.create_mob_combatant(atk: 0, str: 10, base_level: 5)

      assert {:ok, 15} = DamageCalculator.calculate_base_attack(attacker)
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

    test "calculates mob base attack with renewal variance band plus batk" do
      # atk 100 -> weapon roll in the 80%-120% band [80, 119]; batk = str(10) + level(5).
      mob = CombatTestHelper.create_mob_combatant(atk: 100, str: 10, base_level: 5)

      # Run multiple times to test variance
      results =
        for _ <- 1..50 do
          {:ok, atk} = DamageCalculator.calculate_base_attack(mob)
          atk
        end

      # Weapon roll [80, 119] + batk 15 => [95, 134]
      assert Enum.all?(results, fn atk -> atk >= 95 and atk <= 134 end)

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

  describe "calculate_base_attack/2 shield damage base" do
    test "player shield base is stat batk + 4*refine + weight/10" do
      # str 10, dex/luk/level 0 -> stat batk = 20; refine 5 and weight 300 ->
      # 4*5 + div(300, 10) = 50; total 70. The equipped weapon ATK is replaced.
      player =
        CombatTestHelper.create_player_combatant(str: 10, dex: 0, luk: 0, base_level: 0)

      shield_base = 4 * 5 + div(300, 10)

      assert {:ok, 70} = DamageCalculator.calculate_base_attack(player, shield_base: shield_base)
    end

    test "mob ignores the shield base and uses its plain batk" do
      # atk 0 collapses the variance band to 0, so base = str(10) + level(5) = 15,
      # regardless of any shield_base passed through (mobs carry no shield).
      mob = CombatTestHelper.create_mob_combatant(atk: 0, str: 10, base_level: 5)

      assert {:ok, 15} = DamageCalculator.calculate_base_attack(mob, shield_base: 999)
    end
  end

  describe "apply_modifier_pipeline/3" do
    test "applies all modifiers in sequence" do
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 110 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.5 end)

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
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert {:ok, result} = DamageCalculator.apply_modifier_pipeline(100, attacker, defender)
      # No modifiers = no change
      assert result == 100
    end

    test "adds flat weapon ATK (:watk) granted by statuses (SC_LOUD / Impositio)" do
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{watk: 30} end)

      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert {:ok, result} = DamageCalculator.apply_modifier_pipeline(100, attacker, defender)
      # SC_LOUD's +30 base ATK flows into damage as flat weapon ATK
      assert result == 130
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

    test "applies renewal defense formula to a skill-unit cell defender" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      mob = CombatTestHelper.create_mob_combatant(def: 30)

      wall = %{
        mob
        | unit_id: 1,
          unit_type: :skill_unit,
          combat_stats: Map.put(mob.combat_stats, :soft_def, 5)
      }

      assert {:ok, final_damage} = DamageCalculator.apply_defense_formula(150, wall)

      # Expected: 150 * (4000 + 30) / (4000 + 300) - 5
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

    test "converts the display-scale combat critical rate to tenths once" do
      attacker = CombatTestHelper.create_player_combatant(luk: 0)
      attacker = %{attacker | combat_stats: Map.put(attacker.combat_stats, :critical, 5)}

      expect(CriticalHits, :calculate_critical_hit, fn %{critical: 50}, 100 ->
        %{damage: 100, is_critical: false, critical_rate: 50}
      end)

      assert {:ok, %{critical_rate: 50}} = DamageCalculator.apply_critical_hit(100, attacker)
    end

    test "preserves LUK's tenths remainder when Mace Mastery changes displayed critical" do
      attacker = CombatTestHelper.create_player_combatant(luk: 5)
      attacker = %{attacker | combat_stats: Map.put(attacker.combat_stats, :critical, 6)}

      expect(CriticalHits, :calculate_critical_hit, fn %{critical: 66}, 100 ->
        %{damage: 100, is_critical: false, critical_rate: 66}
      end)

      assert {:ok, %{critical_rate: 66}} = DamageCalculator.apply_critical_hit(100, attacker)
    end

    test "adds display-scale status and equipment critical without losing LUK precision" do
      attacker = CombatTestHelper.create_player_combatant(luk: 5)

      # LUK 5 contributes 16 tenths; the display value 20 represents its base
      # 1 plus Mace Mastery 5, status 10, and equipment 4.
      attacker = %{attacker | combat_stats: Map.put(attacker.combat_stats, :critical, 20)}

      expect(CriticalHits, :calculate_critical_hit, fn %{critical: 206}, 100 ->
        %{damage: 100, is_critical: false, critical_rate: 206}
      end)

      assert {:ok, %{critical_rate: 206}} = DamageCalculator.apply_critical_hit(100, attacker)
    end
  end

  describe "integration scenarios" do
    test "high level vs low level combat" do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
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
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
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
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
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

  describe "calculate_damage/3 with skill modifiers" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "skill_ratio scales damage above the 100% baseline" do
      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      {attacker, defender} = CombatTestHelper.create_combat_scenario()

      assert {:ok, %{damage: baseline}} =
               DamageCalculator.calculate_damage(attacker, defender, skill_ratio: 100)

      assert {:ok, %{damage: bashed}} =
               DamageCalculator.calculate_damage(attacker, defender, skill_ratio: 400)

      assert bashed > baseline
    end

    test "skip_crit returns a non-critical result without rolling a crit" do
      stub(CriticalHits, :calculate_critical_hit, fn _, _ ->
        flunk("critical roll must be skipped when skip_crit is set")
      end)

      {attacker, defender} = CombatTestHelper.create_combat_scenario()

      assert {:ok, %{is_critical: false}} =
               DamageCalculator.calculate_damage(attacker, defender,
                 skill_ratio: 130,
                 skip_crit: true
               )
    end

    test "bonus_atk adds a flat amount of pre-defense damage" do
      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      # def 0 defender: defense formula is a no-op, so a flat bonus_atk flows
      # straight through to the final damage.
      {attacker, defender} = CombatTestHelper.create_combat_scenario([], def: 0)

      :rand.seed(:exsss, {1, 2, 3})

      assert {:ok, %{damage: baseline}} =
               DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      assert {:ok, %{damage: boosted}} =
               DamageCalculator.calculate_damage(attacker, defender,
                 bonus_atk: 25,
                 skip_crit: true
               )

      assert boosted == baseline + 25
    end

    test "fixed_damage returns exactly that value regardless of stats" do
      stub(CriticalHits, :calculate_critical_hit, fn _, _ ->
        flunk("fixed_damage must bypass the critical roll")
      end)

      attacker = CombatTestHelper.create_player_combatant()

      for def_value <- [0, 50, 500] do
        defender = CombatTestHelper.create_mob_combatant(def: def_value)

        assert {:ok, %{damage: 50, is_critical: false}} =
                 DamageCalculator.calculate_damage(attacker, defender,
                   fixed_damage: 50,
                   skill_ratio: 400,
                   skip_crit: false
                 )
      end
    end
  end

  describe "calculate_damage_simple_defense/3" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      :ok
    end

    test "drops hard DEF as a flat subtraction, not the renewal curve" do
      attacker = CombatTestHelper.create_player_combatant()
      undefended = CombatTestHelper.create_mob_combatant(def: 0)
      defended = CombatTestHelper.create_mob_combatant(def: 100)

      # Scale damage well above the DEF so neither result hits the min-1 clamp.
      opts = [skill_ratio: 1_000, skip_crit: true]

      :rand.seed(:exsss, {7, 8, 9})

      assert {:ok, %{damage: without_def}} =
               DamageCalculator.calculate_damage_simple_defense(attacker, undefended, opts)

      :rand.seed(:exsss, {7, 8, 9})

      assert {:ok, %{damage: with_def}} =
               DamageCalculator.calculate_damage_simple_defense(attacker, defended, opts)

      # A mob carries no soft DEF, so 100 hard DEF is subtracted flat.
      assert without_def - with_def == 100
    end

    test "still clamps to a minimum of 1 against overwhelming DEF" do
      attacker = CombatTestHelper.create_player_combatant()
      wall = CombatTestHelper.create_mob_combatant(def: 100_000)

      assert {:ok, %{damage: 1}} =
               DamageCalculator.calculate_damage_simple_defense(attacker, wall, skip_crit: true)
    end
  end

  describe "mob status modifier lookup key" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      :ok
    end

    test "sc_provoke on mob lowers effective DEF in damage calculation" do
      mob = CombatTestHelper.create_mob_combatant(unit_id: 5003, def: 50)
      player = CombatTestHelper.create_player_combatant()

      stub(ModifierCalculator, :get_all_modifiers, fn
        :mob, 5003 -> %{def_bonus: -25}
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {1, 2, 3})
      assert {:ok, result_with_provoke} = DamageCalculator.calculate_damage(player, mob)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      :rand.seed(:exsss, {1, 2, 3})
      assert {:ok, result_without_provoke} = DamageCalculator.calculate_damage(player, mob)

      assert result_with_provoke.damage > result_without_provoke.damage
    end
  end

  describe "Demon Bane additive ATK (vs undead/demon)" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :player_human end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "raises physical damage vs an undead mob by the exact additive bonus" do
      # def 0 mob: the renewal defense formula is a no-op, so the flat Demon Bane
      # ATK flows straight through to the final damage. base_level 40, level 5 =>
      # 5 * (40/20 + 3) = 25.
      attacker = %{CombatTestHelper.create_player_combatant(base_level: 40) | demon_bane_level: 5}
      undead_mob = CombatTestHelper.create_mob_combatant(race: :undead, def: 0)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: with_bane}} =
        DamageCalculator.calculate_damage(attacker, undead_mob, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: without_bane}} =
        DamageCalculator.calculate_damage(
          %{attacker | demon_bane_level: 0},
          undead_mob,
          skip_crit: true
        )

      assert with_bane - without_bane == 25
    end

    test "leaves physical damage unchanged vs a non-undead/demon target" do
      attacker = %{CombatTestHelper.create_player_combatant(base_level: 40) | demon_bane_level: 5}
      brute_mob = CombatTestHelper.create_mob_combatant(race: :brute, def: 0)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: with_bane}} =
        DamageCalculator.calculate_damage(attacker, brute_mob, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: without_bane}} =
        DamageCalculator.calculate_damage(
          %{attacker | demon_bane_level: 0},
          brute_mob,
          skip_crit: true
        )

      assert with_bane == without_bane
    end

    test "flows the Demon Bane ATK through the defense reduction (def > 0)" do
      # With DEF > 0 the renewal formula scales the flat +25 ATK down, so the
      # final-damage delta is the DEF-reduced amount: still positive, but
      # strictly less than the raw bonus (it is not applied post-defense).
      attacker = %{CombatTestHelper.create_player_combatant(base_level: 40) | demon_bane_level: 5}
      undead_mob = CombatTestHelper.create_mob_combatant(race: :undead, def: 60)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: with_bane}} =
        DamageCalculator.calculate_damage(attacker, undead_mob, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: without_bane}} =
        DamageCalculator.calculate_damage(
          %{attacker | demon_bane_level: 0},
          undead_mob,
          skip_crit: true
        )

      delta = with_bane - without_bane
      assert delta > 0
      assert delta < 25
    end
  end

  describe "Beast Bane additive ATK (vs Brute/Insect)" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :player_human end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "raises physical damage vs a Brute mob by exactly four ATK per level" do
      attacker = %{CombatTestHelper.create_player_combatant() | beast_bane_level: 5}
      brute_mob = CombatTestHelper.create_mob_combatant(race: :brute, def: 0)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: with_bane}} =
        DamageCalculator.calculate_damage(attacker, brute_mob, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: without_bane}} =
        DamageCalculator.calculate_damage(
          %{attacker | beast_bane_level: 0},
          brute_mob,
          skip_crit: true
        )

      assert with_bane - without_bane == 20
    end

    test "raises physical damage vs an Insect mob by exactly four ATK per level" do
      attacker = %{CombatTestHelper.create_player_combatant() | beast_bane_level: 3}
      insect_mob = CombatTestHelper.create_mob_combatant(race: :insect, def: 0)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: with_bane}} =
        DamageCalculator.calculate_damage(attacker, insect_mob, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: without_bane}} =
        DamageCalculator.calculate_damage(
          %{attacker | beast_bane_level: 0},
          insect_mob,
          skip_crit: true
        )

      assert with_bane - without_bane == 12
    end

    test "flows Beast Bane ATK through defense reduction" do
      attacker = %{CombatTestHelper.create_player_combatant() | beast_bane_level: 5}
      brute_mob = CombatTestHelper.create_mob_combatant(race: :brute, def: 60)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: with_bane}} =
        DamageCalculator.calculate_damage(attacker, brute_mob, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: without_bane}} =
        DamageCalculator.calculate_damage(
          %{attacker | beast_bane_level: 0},
          brute_mob,
          skip_crit: true
        )

      delta = with_bane - without_bane
      assert delta > 0
      assert delta < 20
    end
  end

  describe "Divine Protection soft-DEF (vs undead/demon attacker)" do
    setup do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "reduces physical damage taken from an undead attacker by the exact soft-DEF bonus" do
      # base_level 50, level 5 => (50/25 + 3) * 5 + 0.5 = 25.5 -> 25 soft-DEF,
      # subtracted from the final damage by the renewal defense formula.
      undead_attacker = CombatTestHelper.create_mob_combatant(race: :undead)
      defender = CombatTestHelper.create_player_combatant(base_level: 50, vit: 5)
      defender = %{defender | combat_stats: %{defender.combat_stats | def: 10}}
      with_dp = %{defender | divine_protection_level: 5}

      {:ok, dmg_no_dp} = DamageCalculator.apply_defense_formula(200, defender, undead_attacker)
      {:ok, dmg_dp} = DamageCalculator.apply_defense_formula(200, with_dp, undead_attacker)

      assert dmg_no_dp - dmg_dp == 25
    end

    test "leaves damage from a non-undead/demon attacker unchanged" do
      brute_attacker = CombatTestHelper.create_mob_combatant(race: :brute)
      defender = CombatTestHelper.create_player_combatant(base_level: 50, vit: 5)
      defender = %{defender | combat_stats: %{defender.combat_stats | def: 10}}
      with_dp = %{defender | divine_protection_level: 5}

      {:ok, dmg_no_dp} = DamageCalculator.apply_defense_formula(200, defender, brute_attacker)
      {:ok, dmg_dp} = DamageCalculator.apply_defense_formula(200, with_dp, brute_attacker)

      assert dmg_no_dp == dmg_dp
    end

    test "apply_defense_formula/2 without an attacker applies no Divine Protection" do
      defender = CombatTestHelper.create_player_combatant(base_level: 50, vit: 5)
      defender = %{defender | combat_stats: %{defender.combat_stats | def: 10}}
      with_dp = %{defender | divine_protection_level: 5}

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      {:ok, dmg_plain} = DamageCalculator.apply_defense_formula(200, defender)
      {:ok, dmg_with_dp_field} = DamageCalculator.apply_defense_formula(200, with_dp)

      assert dmg_plain == dmg_with_dp_field
    end
  end

  describe "Dragonology physical race modifier (vs Dragon race)" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "raises physical damage vs a Dragon-race mob by 4*lv percent, levels 1 and 5" do
      dragon = CombatTestHelper.create_mob_combatant(race: :dragon)
      attacker_lv0 = %{CombatTestHelper.create_player_combatant() | dragonology_level: 0}
      attacker_lv1 = %{CombatTestHelper.create_player_combatant() | dragonology_level: 1}
      attacker_lv5 = %{CombatTestHelper.create_player_combatant() | dragonology_level: 5}

      {:ok, base} = DamageCalculator.apply_modifier_pipeline(1000, attacker_lv0, dragon)
      {:ok, lv1} = DamageCalculator.apply_modifier_pipeline(1000, attacker_lv1, dragon)
      {:ok, lv5} = DamageCalculator.apply_modifier_pipeline(1000, attacker_lv5, dragon)

      assert lv1 == base * 1.04
      assert lv5 == base * 1.20
    end

    test "leaves physical damage unchanged vs a non-Dragon mob" do
      brute = CombatTestHelper.create_mob_combatant(race: :brute)
      attacker = %{CombatTestHelper.create_player_combatant() | dragonology_level: 5}
      no_skill = %{attacker | dragonology_level: 0}

      {:ok, with_skill_dmg} = DamageCalculator.apply_modifier_pipeline(1000, attacker, brute)
      {:ok, without_skill_dmg} = DamageCalculator.apply_modifier_pipeline(1000, no_skill, brute)

      assert with_skill_dmg == without_skill_dmg
    end

    test "reduces physical damage taken from a Dragon-race attacker by 4*lv percent" do
      dragon_attacker = CombatTestHelper.create_mob_combatant(race: :dragon)
      defender_lv0 = %{CombatTestHelper.create_player_combatant() | dragonology_level: 0}
      defender_lv5 = %{CombatTestHelper.create_player_combatant() | dragonology_level: 5}

      {:ok, base} = DamageCalculator.apply_modifier_pipeline(1000, dragon_attacker, defender_lv0)

      {:ok, resisted} =
        DamageCalculator.apply_modifier_pipeline(1000, dragon_attacker, defender_lv5)

      assert resisted == base * 0.80
    end

    test "leaves physical damage unchanged from a non-Dragon attacker" do
      brute_attacker = CombatTestHelper.create_mob_combatant(race: :brute)
      defender = %{CombatTestHelper.create_player_combatant() | dragonology_level: 5}
      no_skill = %{defender | dragonology_level: 0}

      {:ok, with_skill_dmg} =
        DamageCalculator.apply_modifier_pipeline(1000, brute_attacker, defender)

      {:ok, without_skill_dmg} =
        DamageCalculator.apply_modifier_pipeline(1000, brute_attacker, no_skill)

      assert with_skill_dmg == without_skill_dmg
    end
  end

  describe "Divine Protection, Demon Bane and Beast Bane do not affect magic" do
    test "magic damage is identical regardless of passive physical damage levels" do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)

      attacker = %{
        unit_type: :player,
        unit_id: 1001,
        combat_stats: %{matk: 300, mdef: 0, soft_mdef: 0}
      }

      defender = %{
        unit_type: :mob,
        unit_id: 2001,
        combat_stats: %{matk: 0, mdef: 10, soft_mdef: 5},
        element: {:neutral, 1}
      }

      {:ok, plain} = MagicDamageCalculator.calculate_magic_damage(attacker, defender)

      {:ok, boosted} =
        MagicDamageCalculator.calculate_magic_damage(
          attacker
          |> Map.put(:demon_bane_level, 10)
          |> Map.put(:beast_bane_level, 10),
          Map.put(defender, :divine_protection_level, 10)
        )

      assert plain.damage == boosted.damage
    end
  end

  describe "physical damage suppression flags" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    for unit_type <- [:player, :mob],
        weapon_type <- @weapon_types,
        size <- [:small, :medium, :large] do
      test "#{unit_type} #{weapon_type} against #{size} retains the size modifier by default" do
        attacker =
          case unquote(unit_type) do
            :player -> CombatTestHelper.create_player_combatant()
            :mob -> CombatTestHelper.create_mob_combatant()
          end
          |> Map.put(:weapon, %{type: unquote(weapon_type), element: :neutral, size: :all})

        defender = CombatTestHelper.create_mob_combatant(size: unquote(size))
        base_damage = 1_200

        assert {:ok, damage} =
                 DamageCalculator.apply_modifier_pipeline(base_damage, attacker, defender)

        expected =
          base_damage * SizeModifiers.get_modifier(unquote(weapon_type), unquote(size), false) /
            100

        assert damage == expected
      end
    end

    test "ignore_size_penalty bypasses a dagger's large-target penalty" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :dagger)

      attacker = %{
        attacker
        | combat_stats: Map.put(attacker.combat_stats, :ignore_size_penalty, true)
      }

      defender = CombatTestHelper.create_mob_combatant(size: :large)

      assert {:ok, 1_200.0} =
               DamageCalculator.apply_modifier_pipeline(1_200, attacker, defender)
    end

    test "equipment bNoSizeFix bypasses a dagger's large-target penalty" do
      attacker =
        CombatTestHelper.create_player_combatant(weapon_type: :dagger)
        |> Map.put(:equip_modifiers, %{no_size_fix: 1})

      defender = CombatTestHelper.create_mob_combatant(size: :large)

      assert {:ok, 1_200.0} =
               DamageCalculator.apply_modifier_pipeline(1_200, attacker, defender)
    end

    test "max_weapon_damage always uses the true upper endpoint" do
      attacker = CombatTestHelper.create_player_combatant(str: 0, dex: 0, luk: 0, base_level: 0)
      attacker = %{attacker | combat_stats: %{attacker.combat_stats | atk: 100}}

      attacker = %{
        attacker
        | combat_stats: Map.put(attacker.combat_stats, :max_weapon_damage, true)
      }

      :rand.seed(:exsss, {1, 2, 3})

      assert Enum.all?(1..100, fn _ ->
               DamageCalculator.calculate_base_attack(attacker) == {:ok, 120}
             end)
    end

    test "normal weapon damage retains its exclusive upper endpoint" do
      attacker = CombatTestHelper.create_player_combatant(str: 0, dex: 0, luk: 0, base_level: 0)
      attacker = %{attacker | combat_stats: %{attacker.combat_stats | atk: 100}}

      :rand.seed(:exsss, {1, 2, 3})

      assert Enum.all?(1..100, fn _ ->
               {:ok, damage} = DamageCalculator.calculate_base_attack(attacker)
               damage in 80..119
             end)
    end

    test "max weapon damage retains overrefine and the minimum-one floor" do
      attacker = CombatTestHelper.create_player_combatant(str: 0, dex: 0, luk: 0, base_level: 0)

      maximized = %{
        attacker
        | combat_stats:
            attacker.combat_stats
            |> Map.put(:atk, 100)
            |> Map.put(:max_weapon_damage, true)
            |> Map.put(:overrefine_band, 9)
      }

      {:ok, overrefined} = DamageCalculator.calculate_base_attack(maximized)
      assert overrefined in 121..129

      floored = %{
        attacker
        | combat_stats:
            attacker.combat_stats
            |> Map.put(:atk, 0)
            |> Map.put(:max_weapon_damage, true)
      }

      assert DamageCalculator.calculate_base_attack(floored) == {:ok, 1}
    end
  end

  describe "calculate_base_attack/1 weapon-ATK path" do
    test "player equipment ATK (combat_stats.atk) raises melee base attack over a bare-handed player" do
      bare_handed = CombatTestHelper.create_player_combatant()
      bare_handed = %{bare_handed | combat_stats: %{bare_handed.combat_stats | atk: 0}}

      equipped = CombatTestHelper.create_player_combatant()
      equipped = %{equipped | combat_stats: %{equipped.combat_stats | atk: 100}}

      {:ok, bare_handed_atk} = DamageCalculator.calculate_base_attack(bare_handed)
      {:ok, equipped_atk} = DamageCalculator.calculate_base_attack(equipped)

      assert equipped_atk > bare_handed_atk
    end

    test "mob base attack is unaffected by the player weapon-ATK path change" do
      mob = CombatTestHelper.create_mob_combatant(atk: 100, str: 10, base_level: 5)

      results =
        for _ <- 1..50 do
          {:ok, atk} = DamageCalculator.calculate_base_attack(mob)
          atk
        end

      assert Enum.all?(results, fn atk -> atk >= 95 and atk <= 134 end)
    end

    test "adds a per-hit overrefine extra within 1..band to the weapon-ATK contribution" do
      overrefine_band = 9

      :rand.seed(:exsss, {1, 2, 3})
      bare = CombatTestHelper.create_player_combatant()
      {:ok, base_atk} = DamageCalculator.calculate_base_attack(bare)

      :rand.seed(:exsss, {1, 2, 3})

      refined = %{
        bare
        | combat_stats: Map.put(bare.combat_stats, :overrefine_band, overrefine_band)
      }

      {:ok, boosted_atk} = DamageCalculator.calculate_base_attack(refined)

      assert (boosted_atk - base_atk) in 1..overrefine_band
    end

    test "an overrefine_band of 0 adds nothing to the weapon-ATK contribution" do
      :rand.seed(:exsss, {1, 2, 3})
      bare = CombatTestHelper.create_player_combatant()
      {:ok, base_atk} = DamageCalculator.calculate_base_attack(bare)

      :rand.seed(:exsss, {1, 2, 3})
      zero_band = %{bare | combat_stats: Map.put(bare.combat_stats, :overrefine_band, 0)}
      {:ok, same_atk} = DamageCalculator.calculate_base_attack(zero_band)

      assert same_atk == base_atk
    end
  end

  describe "calculate_base_attack/1 mastery bonus" do
    test "adds combat_stats.passive_atk for a player attacker" do
      :rand.seed(:exsss, {1, 2, 3})
      no_bonus = CombatTestHelper.create_player_combatant(passive_atk: 0)
      {:ok, base} = DamageCalculator.calculate_base_attack(no_bonus)

      :rand.seed(:exsss, {1, 2, 3})
      with_bonus = CombatTestHelper.create_player_combatant(passive_atk: 20)
      {:ok, boosted} = DamageCalculator.calculate_base_attack(with_bonus)

      assert boosted == base + 20
    end

    test "mob attacker is unaffected by passive_atk mastery" do
      mob = CombatTestHelper.create_mob_combatant(atk: 0)
      expected = mob.base_stats.str + mob.progression.base_level
      assert {:ok, ^expected} = DamageCalculator.calculate_base_attack(mob)
    end
  end

  describe "P.Atk / Res physical integration" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "attacker P.Atk doubles the base-ATK contribution before the skill ratio" do
      attacker = CombatTestHelper.create_player_combatant()
      patk_attacker = %{attacker | combat_stats: Map.put(attacker.combat_stats, :patk, 100)}
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: baseline}} =
        DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: doubled}} =
        DamageCalculator.calculate_damage(patk_attacker, defender, skip_crit: true)

      assert doubled == baseline * 2
    end

    test "defender Res of 400 reduces pre-DEF damage by 40%" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant(def: 0)
      res_defender = %{defender | combat_stats: Map.put(defender.combat_stats, :res, 400)}

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: baseline}} =
        DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: reduced}} =
        DamageCalculator.calculate_damage(attacker, res_defender, skip_crit: true)

      assert reduced == baseline - trunc(400 / 800 * 0.8 * baseline)
    end

    test "a mob defender with no :res key takes full damage without crashing" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      refute Map.has_key?(defender.combat_stats, :res)

      assert {:ok, %{damage: damage}} =
               DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      assert damage > 0
    end

    test "fixed_damage bypasses both P.Atk and Res" do
      attacker = CombatTestHelper.create_player_combatant()
      patk_attacker = %{attacker | combat_stats: Map.put(attacker.combat_stats, :patk, 100)}
      defender = CombatTestHelper.create_mob_combatant()
      res_defender = %{defender | combat_stats: Map.put(defender.combat_stats, :res, 400)}

      assert {:ok, %{damage: 50}} =
               DamageCalculator.calculate_damage(patk_attacker, res_defender,
                 fixed_damage: 50,
                 skip_crit: true
               )
    end
  end

  describe "status combat modifiers (atk_rate / def_rate / phys_damage_reduction)" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)
      :ok
    end

    test "atk_rate scales physical damage additively" do
      # def 0 defender: the renewal formula is a no-op, so a +100% atk_rate on the
      # attacker exactly doubles the final damage.
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001, def: 0)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :rand.seed(:exsss, {1, 2, 3})
      {:ok, base} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{atk_rate: 100}
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {1, 2, 3})
      {:ok, boosted} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      assert boosted.damage == base.damage * 2
    end

    test "def_rate lowers the defender's hard DEF and raises damage" do
      # Freeze's def_rate: -50 halves eDEF, so damage through the renewal formula rises.
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001, def: 100)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :rand.seed(:exsss, {1, 2, 3})
      {:ok, base} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      stub(ModifierCalculator, :get_all_modifiers, fn
        :mob, 2001 -> %{def_rate: -50}
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {1, 2, 3})
      {:ok, reduced_def} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      assert reduced_def.damage > base.damage
    end

    test "phys_damage_reduction shrugs off a percent of final damage and clamps at 100" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant(unit_id: 2001, def: 0)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :rand.seed(:exsss, {1, 2, 3})
      {:ok, base} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      stub(ModifierCalculator, :get_all_modifiers, fn
        :mob, 2001 -> %{phys_damage_reduction: 50}
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {1, 2, 3})
      {:ok, halved} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      assert halved.damage < base.damage

      # A reduction over 100 clamps to 100, so all damage is shrugged off and the
      # min-1 floor applies.
      stub(ModifierCalculator, :get_all_modifiers, fn
        :mob, 2001 -> %{phys_damage_reduction: 150}
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, fully_reduced} =
        DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      assert fully_reduced.damage == 1
    end
  end

  describe "equipment damage families (physical)" do
    setup do
      # Neutralize the size/element resistance steps so each test isolates the
      # equipment family under test. RaceModifiers is left un-stubbed so the
      # Dragonology passive still runs (0 at level 0).
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "a +20% vs-brute weapon multiplies damage by exactly 1.2, inert vs a non-brute" do
      attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:addrace, :brute} => 20}
      }

      plain = CombatTestHelper.create_player_combatant()
      brute = CombatTestHelper.create_mob_combatant(race: :brute)
      fish = CombatTestHelper.create_mob_combatant(race: :fish)

      {:ok, base_vs_brute} = DamageCalculator.apply_modifier_pipeline(1000, plain, brute)
      {:ok, boosted_vs_brute} = DamageCalculator.apply_modifier_pipeline(1000, attacker, brute)

      {:ok, base_vs_fish} = DamageCalculator.apply_modifier_pipeline(1000, plain, fish)
      {:ok, boosted_vs_fish} = DamageCalculator.apply_modifier_pipeline(1000, attacker, fish)

      assert boosted_vs_brute == base_vs_brute * 1.2
      assert boosted_vs_fish == base_vs_fish
    end

    test "bLongAtkRate boosts a bow attacker and is inert on the same sword attacker" do
      target = CombatTestHelper.create_mob_combatant()

      bow = CombatTestHelper.create_player_combatant(weapon_type: :bow)
      sword = CombatTestHelper.create_player_combatant(weapon_type: :sword)

      {:ok, base_bow} = DamageCalculator.apply_modifier_pipeline(1000, bow, target)
      {:ok, base_sword} = DamageCalculator.apply_modifier_pipeline(1000, sword, target)

      {:ok, boosted_bow} =
        DamageCalculator.apply_modifier_pipeline(
          1000,
          %{bow | equip_modifiers: %{long_atk_rate: 20}},
          target
        )

      {:ok, boosted_sword} =
        DamageCalculator.apply_modifier_pipeline(
          1000,
          %{sword | equip_modifiers: %{long_atk_rate: 20}},
          target
        )

      assert boosted_bow == base_bow * 1.2
      assert boosted_sword == base_sword
    end

    test "bShortAtkRate boosts a sword attacker and is inert on the same bow attacker" do
      target = CombatTestHelper.create_mob_combatant()

      bow = CombatTestHelper.create_player_combatant(weapon_type: :bow)
      sword = CombatTestHelper.create_player_combatant(weapon_type: :sword)

      {:ok, base_bow} = DamageCalculator.apply_modifier_pipeline(1000, bow, target)
      {:ok, base_sword} = DamageCalculator.apply_modifier_pipeline(1000, sword, target)

      {:ok, boosted_bow} =
        DamageCalculator.apply_modifier_pipeline(
          1000,
          %{bow | equip_modifiers: %{short_atk_rate: 20}},
          target
        )

      {:ok, boosted_sword} =
        DamageCalculator.apply_modifier_pipeline(
          1000,
          %{sword | equip_modifiers: %{short_atk_rate: 20}},
          target
        )

      assert boosted_sword == base_sword * 1.2
      assert boosted_bow == base_bow
    end

    test "a mob attacker carries no equipment, so both range families read zero" do
      attacker = CombatTestHelper.create_mob_combatant()

      assert attacker.equip_modifiers == %{}
      assert EquipmentBonuses.short_atk_rate(attacker) == 0
      assert EquipmentBonuses.long_atk_rate(attacker) == 0
    end

    test "a +20% race family and a +20% size family stack multiplicatively to exactly 1.44" do
      attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:addrace, :brute} => 20, {:addsize, :medium} => 20}
      }

      target = CombatTestHelper.create_mob_combatant(race: :brute, size: :medium)

      {:ok, base} =
        DamageCalculator.apply_modifier_pipeline(
          1000,
          CombatTestHelper.create_player_combatant(),
          target
        )

      {:ok, stacked} = DamageCalculator.apply_modifier_pipeline(1000, attacker, target)

      assert stacked == base * 1.44
    end

    test "a defender {:subrace, attacker-race} card reduces incoming damage by the percent" do
      attacker = CombatTestHelper.create_player_combatant(race: :player_human)

      defender = %{
        CombatTestHelper.create_mob_combatant()
        | equip_modifiers: %{{:subrace, :player_human} => 20}
      }

      plain_defender = CombatTestHelper.create_mob_combatant()

      {:ok, base} = DamageCalculator.apply_modifier_pipeline(1000, attacker, plain_defender)
      {:ok, reduced} = DamageCalculator.apply_modifier_pipeline(1000, attacker, defender)

      assert reduced == base * 0.8
    end

    test "{:skill_atk, id} applies only when the :skill_id opt matches" do
      skill_id = 1234

      attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:skill_atk, skill_id} => 50}
      }

      defender = CombatTestHelper.create_mob_combatant()

      {:ok, without_skill} = DamageCalculator.apply_modifier_pipeline(1000, attacker, defender)

      {:ok, matched} =
        DamageCalculator.apply_modifier_pipeline(1000, attacker, defender, skill_id: skill_id)

      {:ok, mismatched} =
        DamageCalculator.apply_modifier_pipeline(1000, attacker, defender, skill_id: 9999)

      assert without_skill == 1000.0
      assert matched == 1500
      assert mismatched == without_skill
    end

    test "{:skill_atk, id} reaches the full calculate_damage path through the :skill_id opt" do
      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      skill_id = 1234

      attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:skill_atk, skill_id} => 100}
      }

      defender = CombatTestHelper.create_mob_combatant(def: 0)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: without_skill}} =
        DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, %{damage: with_skill}} =
        DamageCalculator.calculate_damage(attacker, defender, skip_crit: true, skill_id: skill_id)

      assert with_skill == without_skill * 2
    end

    test "{:addele, e} keys on the defender's own defense element" do
      attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:addele, :earth} => 20}
      }

      earth_mob = CombatTestHelper.create_mob_combatant(element: {:earth, 1})
      fire_mob = CombatTestHelper.create_mob_combatant(element: {:fire, 1})

      {:ok, vs_earth} = DamageCalculator.apply_modifier_pipeline(1000, attacker, earth_mob)
      {:ok, vs_fire} = DamageCalculator.apply_modifier_pipeline(1000, attacker, fire_mob)

      assert vs_earth == 1200
      assert vs_fire == 1000.0
    end

    test "{:subele, e} keys on the post-endow effective attack element, not the raw weapon" do
      # The attacker wields a neutral weapon but an :attack_element status endows
      # fire; the defender's {:subele, :fire} card must bite off the endowed
      # element, proving the effective attack element threads to the reduction.
      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{attack_element: :fire}
        _, _ -> %{}
      end)

      attacker = CombatTestHelper.create_player_combatant(weapon_element: :neutral)

      fire_resist = %{
        CombatTestHelper.create_mob_combatant()
        | equip_modifiers: %{{:subele, :fire} => 20}
      }

      neutral_resist = %{
        CombatTestHelper.create_mob_combatant()
        | equip_modifiers: %{{:subele, :neutral} => 20}
      }

      {:ok, reduced} = DamageCalculator.apply_modifier_pipeline(1000, attacker, fire_resist)
      {:ok, inert} = DamageCalculator.apply_modifier_pipeline(1000, attacker, neutral_resist)

      assert reduced == 800
      assert inert == 1000.0
    end

    test "a boss-class defender picks up the {:addclass, :boss} family" do
      attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:addclass, :boss} => 30}
      }

      boss = CombatTestHelper.create_boss_mob()
      normal = CombatTestHelper.create_mob_combatant()

      {:ok, vs_boss} = DamageCalculator.apply_modifier_pipeline(1000, attacker, boss)
      {:ok, vs_normal} = DamageCalculator.apply_modifier_pipeline(1000, attacker, normal)

      assert vs_boss == 1300
      assert vs_normal == 1000.0
    end

    test "Dragonology passive and {:addrace, :dragon} equipment sum into one race step" do
      attacker = %{
        CombatTestHelper.create_player_combatant()
        | dragonology_level: 5,
          equip_modifiers: %{{:addrace, :dragon} => 20}
      }

      dragon = CombatTestHelper.create_mob_combatant(race: :dragon)

      {:ok, total} = DamageCalculator.apply_modifier_pipeline(1000, attacker, dragon)

      # One race+class accumulator: Dragonology 4*5 + equipment 20 = 40,
      # div(1000 * 140, 100) = 1400 — summed, never compounded.
      assert total == 1400
    end
  end

  describe "ignore-def equipment family (physical defense formula)" do
    setup do
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :ok
    end

    test "100% ignore-def drops the defender's hard DEF contribution to nothing" do
      brute_defender = CombatTestHelper.create_mob_combatant(race: :brute, def: 100)
      no_def_defender = CombatTestHelper.create_mob_combatant(race: :brute, def: 0)

      attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:ignore_def_race, :brute} => 100}
      }

      {:ok, fully_ignored} =
        DamageCalculator.apply_defense_formula(200, brute_defender, attacker)

      {:ok, no_def_baseline} = DamageCalculator.apply_defense_formula(200, no_def_defender)

      assert fully_ignored == no_def_baseline
    end

    test "0% ignore-def is bit-identical to the no-equipment baseline" do
      brute_defender = CombatTestHelper.create_mob_combatant(race: :brute, def: 100)

      zero_attacker = %{
        CombatTestHelper.create_player_combatant()
        | equip_modifiers: %{{:ignore_def_race, :brute} => 0}
      }

      {:ok, baseline} = DamageCalculator.apply_defense_formula(200, brute_defender)

      {:ok, with_zero_ignore} =
        DamageCalculator.apply_defense_formula(200, brute_defender, zero_attacker)

      assert with_zero_ignore == baseline
    end
  end

  describe "hand-specific cardfix channels" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

      {:ok,
       left_hand: %WeaponHand{
         item_id: 2,
         subtype: :dagger,
         element: :neutral,
         base_atk: 0,
         refine_atk: 0,
         overrefine_band: 0,
         slot: :left_hand
       }}
    end

    test "primary and IgnoreAtkCard preserve scripted aggregate weapon element" do
      right = %WeaponHand{
        item_id: 1,
        subtype: :dagger,
        element: :fire,
        base_atk: 100,
        refine_atk: 0,
        overrefine_band: 0,
        slot: :right_hand
      }

      attacker =
        CombatTestHelper.create_player_combatant(weapon_type: :dagger, weapon_element: :holy)
        |> Map.put(:right_hand, right)

      defender =
        CombatTestHelper.create_mob_combatant(def: 0)
        |> Map.put(:element, {:earth, 1})

      opts = [base_damage: 1_000, skip_crit: true]

      expect(ElementModifiers, :get_modifier, 2, fn attack_element, _, _, _ ->
        assert attack_element == :holy
        1.0
      end)

      assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender, opts)

      assert {:ok, _} =
               DamageCalculator.calculate_damage_ignoring_attacker_cards(attacker, defender, opts)
    end

    test "secondary damage fails when the attacker has no left-hand snapshot" do
      attacker = CombatTestHelper.create_player_combatant()
      defender = CombatTestHelper.create_mob_combatant()

      assert {:error, :no_left_hand} =
               DamageCalculator.calculate_secondary_hand_damage(attacker, defender,
                 fixed_damage: 1_000
               )
    end

    test "primary, secondary, and IgnoreAtkCard separate cardfix from equipment DEF-ignore", %{
      left_hand: left_hand
    } do
      attacker = %{
        CombatTestHelper.create_player_combatant()
        | left_hand: left_hand,
          equip_modifiers: %{
            {:addrace, :brute} => 100,
            {:ignore_def_race, :brute} => 100
          }
      }

      defender = CombatTestHelper.create_mob_combatant(race: :brute, def: 100)
      opts = [base_damage: 1_000, skip_crit: true]

      assert {:ok, %{damage: 2_000}} =
               DamageCalculator.calculate_damage(attacker, defender, opts)

      assert {:ok, %{damage: 1_000}} =
               DamageCalculator.calculate_damage_ignoring_attacker_cards(attacker, defender, opts)

      assert {:ok, %{damage: 820}} =
               DamageCalculator.calculate_secondary_hand_damage(attacker, defender, opts)
    end

    test "restricted paths retain skill, range, status, passive, and defender channels", %{
      left_hand: left_hand
    } do
      attacker = %{
        CombatTestHelper.create_player_combatant(weapon_type: :sword)
        | left_hand: left_hand,
          dragonology_level: 5,
          equip_modifiers: %{
            {:addrace, :dragon} => 100,
            {:skill_atk, 123} => 20,
            short_atk_rate: 25
          }
      }

      defender = %{
        CombatTestHelper.create_mob_combatant(race: :dragon, def: 0)
        | equip_modifiers: %{{:subrace, :human} => 10}
      }

      stub(ModifierCalculator, :get_all_modifiers, fn
        :player, 1001 -> %{atk_rate: 50}
        _, _ -> %{}
      end)

      opts = [base_damage: 1_000, skill_id: 123, skip_crit: true]

      no_cards = %{
        attacker
        | equip_modifiers: Map.delete(attacker.equip_modifiers, {:addrace, :dragon})
      }

      assert {:ok, %{damage: 2_430}} =
               DamageCalculator.calculate_damage(no_cards, defender, opts)

      assert {:ok, %{damage: 2_430}} =
               DamageCalculator.calculate_damage_ignoring_attacker_cards(attacker, defender, opts)

      assert {:ok, %{damage: 2_430}} =
               DamageCalculator.calculate_secondary_hand_damage(attacker, defender, opts)
    end

    test "primary and IgnoreAtkCard use the left hand magnitude in a left-only loadout" do
      left = %WeaponHand{
        item_id: 2,
        subtype: :dagger,
        element: :water,
        base_atk: 50,
        refine_atk: 10,
        overrefine_band: 0,
        slot: :left_hand
      }

      attacker =
        CombatTestHelper.create_player_combatant(str: 0, dex: 0, luk: 0, base_level: 0)
        |> Map.put(:left_hand, left)
        |> Map.put(:weapon, %{type: :dagger, element: :water, size: :all})
        |> Map.update!(:combat_stats, fn stats ->
          stats
          |> Map.put(:atk, 60)
          |> Map.put(:max_weapon_damage, true)
        end)

      defender = CombatTestHelper.create_mob_combatant(def: 0)

      assert {:ok, %{damage: 72}} =
               DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      assert {:ok, %{damage: 72}} =
               DamageCalculator.calculate_damage_ignoring_attacker_cards(attacker, defender,
                 skip_crit: true
               )
    end

    test "each calculator reconstructs weapon ATK, refine, overrefine, and element from its selected hand" do
      right = %WeaponHand{
        item_id: 1,
        subtype: :dagger,
        element: :fire,
        base_atk: 100,
        refine_atk: 20,
        overrefine_band: 0,
        slot: :right_hand
      }

      left = %WeaponHand{
        item_id: 2,
        subtype: :dagger,
        element: :water,
        base_atk: 50,
        refine_atk: 10,
        overrefine_band: 1,
        slot: :left_hand
      }

      attacker =
        CombatTestHelper.create_player_combatant(str: 0, dex: 0, luk: 0, base_level: 0)
        |> Map.put(:right_hand, right)
        |> Map.put(:left_hand, left)
        |> Map.put(:weapon, %{type: :dagger, element: :fire, size: :all})
        |> Map.update!(:combat_stats, fn stats ->
          stats
          |> Map.put(:atk, 210)
          |> Map.put(:max_weapon_damage, true)
          |> Map.put(:overrefine_band, 1)
        end)

      defender =
        CombatTestHelper.create_mob_combatant(def: 0)
        |> Map.put(:element, {:earth, 1})

      expect(ElementModifiers, :get_modifier, 3, fn
        :fire, _, _, _ -> 1.0
        :water, _, _, _ -> 2.0
      end)

      assert {:ok, %{damage: 180}} =
               DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      assert {:ok, %{damage: 180}} =
               DamageCalculator.calculate_damage_ignoring_attacker_cards(attacker, defender,
                 skip_crit: true
               )

      assert {:ok, %{damage: 218}} =
               DamageCalculator.calculate_secondary_hand_damage(attacker, defender,
                 skip_crit: true
               )
    end
  end

  describe "status combat-families bridge (damage-taken side)" do
    setup do
      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      :ok
    end

    defp damage_with_defender_modifiers(attacker, defender, modifiers) do
      defender_id = defender.unit_id

      stub(ModifierCalculator, :get_all_modifiers, fn
        _, ^defender_id -> modifiers
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {11, 22, 33})
      {:ok, result} = DamageCalculator.calculate_damage(attacker, defender)
      result.damage
    end

    test "ranged_damage_taken_rate: -20 reduces long-range weapon damage ~20%" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :bow)
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      baseline = damage_with_defender_modifiers(attacker, defender, %{})

      reduced =
        damage_with_defender_modifiers(attacker, defender, %{ranged_damage_taken_rate: -20})

      assert_in_delta reduced / baseline, 0.80, 0.02
    end

    test "the per-hit ranged opt triggers the reduction with a melee weapon equipped" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :sword)
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      baseline = damage_with_defender_modifiers(attacker, defender, %{})

      stub(ModifierCalculator, :get_all_modifiers, fn
        _, unit_id when unit_id == defender.unit_id -> %{ranged_damage_taken_rate: -20}
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {11, 22, 33})
      {:ok, result} = DamageCalculator.calculate_damage(attacker, defender, ranged: true)

      assert_in_delta result.damage / baseline, 0.80, 0.02
    end

    test "a long attack range attacker (ranged mob) triggers the reduction" do
      attacker = %{CombatTestHelper.create_mob_combatant() | attack_range: 7}
      defender = CombatTestHelper.create_player_combatant()

      baseline = damage_with_defender_modifiers(attacker, defender, %{})

      reduced =
        damage_with_defender_modifiers(attacker, defender, %{ranged_damage_taken_rate: -20})

      assert_in_delta reduced / baseline, 0.80, 0.02
    end

    test "ranged_damage_taken_rate leaves melee weapon damage untouched" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :sword)
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      baseline = damage_with_defender_modifiers(attacker, defender, %{})

      melee =
        damage_with_defender_modifiers(attacker, defender, %{ranged_damage_taken_rate: -20})

      assert melee == baseline
    end

    test "each elemental status key reduces matching physical damage for a mob defender" do
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      for {element, key} <- @element_status_keys do
        attacker = CombatTestHelper.create_player_combatant(weapon_element: element)
        modifiers = %{key => 25}
        baseline = damage_with_defender_modifiers(attacker, defender, %{})
        reduced = damage_with_defender_modifiers(attacker, defender, modifiers)

        assert_in_delta reduced / baseline, 0.75, 0.02
      end
    end

    test "each elemental status key reduces matching physical damage for a player defender" do
      defender = CombatTestHelper.create_player_combatant(unit_id: 1002, vit: 1)

      for {element, key} <- @element_status_keys do
        mob = CombatTestHelper.create_mob_combatant()
        attacker = %{mob | weapon: %{mob.weapon | element: element}}
        modifiers = %{key => 25}
        baseline = damage_with_defender_modifiers(attacker, defender, %{})
        reduced = damage_with_defender_modifiers(attacker, defender, modifiers)

        assert_in_delta reduced / baseline, 0.75, 0.02
      end
    end

    test "subele_holy: 25 reduces incoming holy damage ~25%" do
      attacker = CombatTestHelper.create_player_combatant(weapon_element: :holy)
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      baseline = damage_with_defender_modifiers(attacker, defender, %{})
      reduced = damage_with_defender_modifiers(attacker, defender, %{subele_holy: 25})

      assert_in_delta reduced / baseline, 0.75, 0.02
    end

    test "an elemental status key is inert against another physical element" do
      attacker = CombatTestHelper.create_player_combatant(weapon_element: :fire)
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      baseline = damage_with_defender_modifiers(attacker, defender, %{})
      unaffected = damage_with_defender_modifiers(attacker, defender, %{subele_water: 25})

      assert unaffected == baseline
    end

    test "subrace_demon: 25 reduces damage from a demon-race attacker ~25%" do
      attacker = CombatTestHelper.create_mob_combatant(race: :demon)
      defender = CombatTestHelper.create_mob_combatant(unit_id: 3001, def: 0)

      baseline = damage_with_defender_modifiers(attacker, defender, %{})
      reduced = damage_with_defender_modifiers(attacker, defender, %{subrace_demon: 25})

      assert_in_delta reduced / baseline, 0.75, 0.02
    end

    test "status and equipment resist for the same element family combine" do
      attacker = CombatTestHelper.create_player_combatant(weapon_element: :holy)
      clean = CombatTestHelper.create_mob_combatant(def: 0)
      equipped = Map.put(clean, :equip_modifiers, %{{:subele, :holy} => 10})

      baseline = damage_with_defender_modifiers(attacker, clean, %{})
      equip_only = damage_with_defender_modifiers(attacker, equipped, %{})
      combined = damage_with_defender_modifiers(attacker, equipped, %{subele_holy: 25})

      assert_in_delta equip_only / baseline, 0.90, 0.02
      assert_in_delta combined / baseline, 0.65, 0.02
      assert combined < equip_only
    end
  end
end
