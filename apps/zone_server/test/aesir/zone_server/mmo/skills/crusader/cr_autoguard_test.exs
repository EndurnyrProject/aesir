defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguardTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguard
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry, as: StatusRegistry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpecialEffect

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  @skill_id 249
  @shield_nameid 2101
  @left_hand 0x20

  # Block chance percent by level, mirroring the status' own table.
  @block_chance {5, 10, 14, 18, 21, 24, 26, 28, 29, 30}

  describe "catalog" do
    test "resolves CR_AUTOGUARD as a self-target toggle" do
      {:ok, definition} = Catalog.by_id(@skill_id)

      assert definition.name == :cr_autoguard
      assert definition.max_level == 10
      assert definition.target_type == :self
      assert definition.sp_cost == [12, 14, 16, 18, 20, 22, 24, 26, 28, 30]
    end

    test "resolves the active module by name" do
      assert {:ok, CrAutoguard} = Catalog.active_module_for(:cr_autoguard)
    end
  end

  describe "status block roll" do
    test "a roll at the level's exact block chance intercepts and plays the guard effect" do
      for level <- [1, 5, 10] do
        seed_for_roll(elem(@block_chance, level - 1))
        expect(SpecialEffect, :play, fn {:mob, 7001}, :guard, :area -> :ok end)

        assert {:intercept, :blocked} =
                 Autoguard.before_weapon_hit({:mob, 7001}, entry(level), %{}, %{})
      end
    end

    test "a roll one above the level's block chance lets the hit through, no guard effect" do
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)

      for level <- [1, 5, 10] do
        seed_for_roll(elem(@block_chance, level - 1) + 1)

        assert :continue = Autoguard.before_weapon_hit({:mob, 7002}, entry(level), %{}, %{})
      end
    end

    test "block chance rises with level: the same roll passes at low level and blocks at high" do
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)

      # roll of 25: above lv1 (5) and lv5 (21), at or below lv10 (30).
      seed_for_roll(25)
      assert :continue = Autoguard.before_weapon_hit({:mob, 7003}, entry(1), %{}, %{})

      seed_for_roll(25)
      assert :continue = Autoguard.before_weapon_hit({:mob, 7003}, entry(5), %{}, %{})

      seed_for_roll(25)

      assert {:intercept, :blocked} =
               Autoguard.before_weapon_hit({:mob, 7003}, entry(10), %{}, %{})
    end

    test "a blocked hit does not consume the status: it keeps guarding" do
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)
      :ok = StatusStorage.apply_status(:mob, 7004, :sc_autoguard, val1: 10)

      seed_for_roll(1)

      assert {:intercept, :blocked} =
               Autoguard.before_weapon_hit({:mob, 7004}, entry(10), %{}, %{})

      assert StatusStorage.has_status?(:mob, 7004, :sc_autoguard)
    end

    test "the status is wired into the weapon-hit interception dispatch" do
      assert :sc_autoguard in StatusRegistry.statuses_implementing(:before_weapon_hit)
    end
  end

  describe "validate/4 shield gate" do
    test "a player with a shield equipped may cast" do
      caster = player_with_shield()

      assert :ok = CrAutoguard.validate(caster, :self, 1, definition())
    end

    test "a player without a shield is refused" do
      caster = player_without_shield()

      assert {:error, :requires_shield} = CrAutoguard.validate(caster, :self, 1, definition())
    end

    test "a mob caster skips the shield gate" do
      assert :ok = CrAutoguard.validate(build_mob(9001), :self, 1, definition())
    end
  end

  describe "cast/4 toggle" do
    test "casting applies the status at the cast level" do
      caster = %PlayerState{character_id: 1000}

      expect(StatusInterpreter, :toggle_status, fn :player, 1000, :sc_autoguard, params ->
        assert Keyword.fetch!(params, :val1) == 7
        {:ok, :applied}
      end)

      assert {:ok, ^caster} = CrAutoguard.cast(caster, :self, 7, definition())
    end

    test "re-casting toggles the status off" do
      caster = %PlayerState{character_id: 1000}

      expect(StatusInterpreter, :toggle_status, fn :player, 1000, :sc_autoguard, _params ->
        {:ok, :removed}
      end)

      assert {:ok, ^caster} = CrAutoguard.cast(caster, :self, 3, definition())
    end

    test "a mob caster toggles on itself" do
      caster = build_mob(9002)

      expect(StatusInterpreter, :toggle_status, fn :mob, 9002, :sc_autoguard, params ->
        assert Keyword.fetch!(params, :val1) == 5
        {:ok, :applied}
      end)

      assert {:ok, ^caster} = CrAutoguard.cast(caster, :self, 5, definition())
    end
  end

  describe "weapon-skill interception through the combat pipeline" do
    setup do
      attacker = CombatTestHelper.create_player_combatant(unit_id: 1000, position: {100, 100})
      target = CombatTestHelper.create_player_combatant(unit_id: 5000, position: {100, 101})
      caster_state = %PlayerState{character_id: 1000}
      target_state = %PlayerState{character_id: 5000}

      stub(PlayerState, :to_combatant, fn
        %PlayerState{character_id: 1000} -> attacker
        %PlayerState{character_id: 5000} -> target
      end)

      stub(TargetResolver, :resolve, fn 5000 -> {:ok, self(), target_state, :player} end)
      stub(TargetResolver, :ensure_targetable, fn _state, _type -> :ok end)
      stub(AttackValidator, :validate, fn _attacker, _target, _opts -> :ok end)
      stub(Targeting, :validate_enemy, fn _attacker, _target -> :ok end)

      {:ok, caster_state: caster_state}
    end

    test "an intercepted weapon skill deals no damage and is tagged non-basic", %{
      caster_state: caster_state
    } do
      expect(StatusInterpreter, :before_weapon_hit, fn :player, 5000, attack_info ->
        assert attack_info.basic_attack? == false
        assert attack_info.target == {:player, 5000}
        {:intercept, :blocked}
      end)

      reject(&DamageCalculator.calculate_damage/3)

      assert :ok =
               SkillAttack.execute_skill_attack(caster_state, 5000,
                 skill_id: 253,
                 skill_level: 1,
                 skill_ratio: 100,
                 skip_range: true
               )
    end
  end

  describe "magic exemption" do
    test "a magic attack never dispatches the weapon-hit interception" do
      attacker = CombatTestHelper.create_player_combatant(unit_id: 1000, position: {150, 150})
      target = CombatTestHelper.create_player_combatant(unit_id: 5000, position: {150, 150})

      caster_state = %PlayerState{character_id: 1000}
      target_state = %PlayerState{character_id: 5000}

      stub(PlayerState, :to_combatant, fn
        %PlayerState{character_id: 1000} -> attacker
        %PlayerState{character_id: 5000} -> target
      end)

      stub(TargetResolver, :resolve, fn 5000 -> {:ok, self(), target_state, :player} end)
      stub(TargetResolver, :ensure_targetable, fn _state, _type -> :ok end)
      stub(AttackValidator, :validate, fn _attacker, _target, _opts -> :ok end)
      stub(Targeting, :validate_enemy, fn _attacker, _target -> :ok end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 30, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      stub(PlayerSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      reject(&StatusInterpreter.before_weapon_hit/3)

      assert :ok =
               Combat.execute_magic_attack(caster_state, 5000,
                 skill_id: 14,
                 skill_level: 10,
                 skill_ratio: 100,
                 element: :fire
               )
    end
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(@skill_id)
    definition
  end

  defp entry(level), do: %StatusEntry{type: :sc_autoguard, val1: level}

  # Seeds `:rand` so the next `:rand.uniform(100)` returns exactly `target`, for a
  # deterministic block roll. Every 1..100 value is reachable, so the search
  # always resolves.
  defp seed_for_roll(target) do
    seed =
      Enum.find(1..50_000, fn candidate ->
        :rand.seed(:exsss, {1, 1, candidate})
        :rand.uniform(100) == target
      end)

    :rand.seed(:exsss, {1, 1, seed})
  end

  defp player_with_shield do
    equipment =
      Stats.equipment_from_inventory([
        %InventoryItem{nameid: @shield_nameid, amount: 1, equip: @left_hand, identify: 1}
      ])

    %PlayerState{character_id: 1000, stats: %Stats{equipment: equipment}}
  end

  defp player_without_shield do
    %PlayerState{character_id: 1000, stats: %Stats{equipment: Stats.equipment_from_inventory([])}}
  end

  defp build_mob(instance_id) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 10,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      modes: []
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    MobState.new(instance_id, mob_data, spawn_ref, "prontera", 150, 150)
  end
end
