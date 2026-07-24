defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefenderTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefender
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Defender
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @caster_id 3100
  @shield_id 2109
  @two_handed_spear_id 1424

  defp caster(equipment \\ %Equipment{}),
    do: %PlayerState{character_id: @caster_id, stats: %{equipment: equipment}}

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1004,
      aegis_name: "test_crusader",
      name: "Test Crusader",
      level: 50,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1004,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9003, mob_data, spawn_ref, "prontera", 100, 100)
  end

  describe "catalog registration" do
    test "by_id(257) resolves cr_defender" do
      assert {:ok, definition} = Catalog.by_id(257)
      assert definition.name == :cr_defender
      assert definition.display_name == "Defending Aura"
      assert definition.max_level == 5
      assert definition.target_type == :self
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 257}} = Catalog.by_name(:cr_defender)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, CrDefender} = Catalog.active_module_for(:cr_defender)
    end
  end

  describe "metadata" do
    test "sp_cost is a flat 30 across all levels" do
      {:ok, definition} = Catalog.by_name(:cr_defender)

      assert definition.sp_cost == [30, 30, 30, 30, 30]
    end
  end

  describe "validate/4 (player shield gate)" do
    test "rejects a cast without a shield equipped" do
      assert {:error, :requires_shield} = CrDefender.validate(caster(), :self, 1, %{})
    end

    test "allows a cast with a shield equipped" do
      assert :ok =
               CrDefender.validate(
                 caster(%Equipment{left_hand: @shield_id}),
                 :self,
                 1,
                 %{}
               )
    end

    test "rejects a cast with a two-handed weapon occupying the left hand" do
      assert {:error, :requires_shield} =
               CrDefender.validate(
                 caster(%Equipment{left_hand: @two_handed_spear_id}),
                 :self,
                 1,
                 %{}
               )
    end
  end

  describe "validate/4 (mob caster bypass)" do
    test "always allows a mob caster regardless of equipment" do
      assert :ok = CrDefender.validate(mob_caster(), :self, 1, %{})
    end
  end

  describe "cast/4" do
    test "toggles sc_defender on the caster with val1 set to the skill level" do
      caster = caster(%Equipment{left_hand: @shield_id})

      expect(StatusInterpreter, :toggle_status, fn :player, @caster_id, :sc_defender, opts ->
        assert opts[:val1] == 3
        {:ok, :applied}
      end)

      assert {:ok, ^caster} = CrDefender.cast(caster, :self, 3, %{})
    end

    test "re-casting toggles the status off" do
      caster = caster(%Equipment{left_hand: @shield_id})

      expect(StatusInterpreter, :toggle_status, fn :player, @caster_id, :sc_defender, _opts ->
        {:ok, :removed}
      end)

      assert {:ok, ^caster} = CrDefender.cast(caster, :self, 3, %{})
    end

    test "a mob caster toggles through :mob, not :player" do
      mob = mob_caster()

      expect(StatusInterpreter, :toggle_status, fn :mob, 9003, :sc_defender, opts ->
        assert opts[:val1] == 5
        {:ok, :applied}
      end)

      assert {:ok, ^mob} = CrDefender.cast(mob, :self, 5, %{})
    end

    test "propagates a toggle error" do
      caster = caster(%Equipment{left_hand: @shield_id})

      expect(StatusInterpreter, :toggle_status, fn :player, @caster_id, :sc_defender, _opts ->
        {:error, :status_blocked}
      end)

      assert {:error, :status_blocked} = CrDefender.cast(caster, :self, 1, %{})
    end
  end

  describe "sc_defender modifiers/2" do
    alias Aesir.ZoneServer.Mmo.StatusEntry

    defp entry(overrides), do: struct(%StatusEntry{type: :sc_defender, state: %{}}, overrides)

    test "lv1 reduces ranged damage taken by 20% and ASPD by 4" do
      assert %{ranged_damage_taken_rate: -20, aspd: -4} = Defender.modifiers(entry(val1: 1), %{})
    end

    test "lv5 reduces ranged damage taken by 80% and ASPD by 20" do
      assert %{ranged_damage_taken_rate: -80, aspd: -20} =
               Defender.modifiers(entry(val1: 5), %{})
    end
  end

  describe "combat: ranged damage reduction, melee/magic untouched" do
    setup do
      Mimic.copy(ElementModifiers)
      Mimic.copy(SizeModifiers)
      Mimic.copy(RaceModifiers)
      Mimic.copy(CriticalHits)
      Mimic.copy(ModifierCalculator)

      stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
      stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
      stub(RaceModifiers, :player_race, fn -> :human end)

      stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
        %{damage: damage, is_critical: false}
      end)

      :ok
    end

    defp damage_with_defender(attacker, defender, level) do
      defender_id = defender.unit_id
      modifiers = Defender.modifiers(%Aesir.ZoneServer.Mmo.StatusEntry{val1: level}, %{})

      stub(ModifierCalculator, :get_all_modifiers, fn
        _, ^defender_id -> modifiers
        _, _ -> %{}
      end)

      :rand.seed(:exsss, {11, 22, 33})
      {:ok, result} = DamageCalculator.calculate_damage(attacker, defender)
      result.damage
    end

    test "lv5 defender reduces long-range weapon hits by 80%" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :bow)
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :rand.seed(:exsss, {11, 22, 33})
      {:ok, baseline_result} = DamageCalculator.calculate_damage(attacker, defender)
      baseline = baseline_result.damage

      reduced = damage_with_defender(attacker, defender, 5)

      assert_in_delta reduced / baseline, 0.20, 0.02
    end

    test "lv5 defender leaves melee weapon hits untouched" do
      attacker = CombatTestHelper.create_player_combatant(weapon_type: :sword)
      defender = CombatTestHelper.create_mob_combatant(def: 0)

      stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
      :rand.seed(:exsss, {11, 22, 33})
      {:ok, baseline_result} = DamageCalculator.calculate_damage(attacker, defender)
      baseline = baseline_result.damage

      melee = damage_with_defender(attacker, defender, 5)

      assert melee == baseline
    end
  end
end
