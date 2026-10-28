defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguardTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
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
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  @skill_id 249
  @venom_knife 1004
  @shield_nameid 2101
  @left_hand 0x20

  # Block chance percent by level, mirroring the status' own table.
  @block_chance {5, 10, 14, 18, 21, 24, 26, 28, 29, 30}

  describe "status block roll" do
    test "a skill marked ignore_auto_guard always passes through, no roll" do
      seed_for_roll(1)
      reject(&SpecialEffect.play/3)

      assert {:ok, 40, _entry} =
               Autoguard.absorb_damage({:mob, 7000}, entry(10), weapon_hit(40, @venom_knife), %{})
    end

    test "a roll at the level's exact block chance stops the hit and plays the guard effect" do
      for level <- [1, 5, 10] do
        seed_for_roll(elem(@block_chance, level - 1))
        expect(SpecialEffect, :play, fn {:mob, 7001}, :guard, :area -> :ok end)

        assert {:ok, 0, _entry} =
                 Autoguard.absorb_damage({:mob, 7001}, entry(level), weapon_hit(40), %{})
      end
    end

    test "a roll one above the level's block chance lets the hit through, no guard effect" do
      reject(&SpecialEffect.play/3)

      for level <- [1, 5, 10] do
        seed_for_roll(elem(@block_chance, level - 1) + 1)

        assert {:ok, 40, _entry} =
                 Autoguard.absorb_damage({:mob, 7002}, entry(level), weapon_hit(40), %{})
      end
    end

    test "block chance rises with level: the same roll passes at low level and blocks at high" do
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)

      # roll of 25: above lv1 (5) and lv5 (21), at or below lv10 (30).
      seed_for_roll(25)
      assert {:ok, 40, _} = Autoguard.absorb_damage({:mob, 7003}, entry(1), weapon_hit(40), %{})

      seed_for_roll(25)
      assert {:ok, 40, _} = Autoguard.absorb_damage({:mob, 7003}, entry(5), weapon_hit(40), %{})

      seed_for_roll(25)
      assert {:ok, 0, _} = Autoguard.absorb_damage({:mob, 7003}, entry(10), weapon_hit(40), %{})
    end

    test "a blocked hit does not consume the status: it keeps guarding" do
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)
      :ok = StatusStorage.apply_status(:mob, 7004, :sc_autoguard, val1: 10)

      seed_for_roll(1)

      assert {:ok, 0, entry} =
               Autoguard.absorb_damage({:mob, 7004}, entry(10), weapon_hit(40), %{})

      assert entry == entry(10)
    end

    test "magic and misc hits pass through untouched, without a roll" do
      seed_for_roll(1)
      reject(&SpecialEffect.play/3)

      for dmg_type <- [:magic, :misc] do
        hit = %{weapon_hit(40) | dmg_type: dmg_type}
        assert {:ok, 40, _} = Autoguard.absorb_damage({:mob, 7005}, entry(10), hit, %{})
      end
    end

    test "a block covered by a valid Devotion link shows the guard on the Crusader, no Shrink" do
      devotee_id = 7006
      crusader_id = 7007
      devote(devotee_id, crusader_id)
      :ok = StatusStorage.apply_status(:player, devotee_id, :sc_shrink, val1: 1)

      seed_for_roll(1)
      expect(SpecialEffect, :play, fn {:player, ^crusader_id}, :guard, :area -> :ok end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, 0, _} =
               Autoguard.absorb_damage({:player, devotee_id}, entry(10), weapon_hit(40), %{})
    end

    test "the status is a blocker of the damage stage, after Kyrie, Safety Wall, Pneuma and Basilica" do
      assert :sc_autoguard in StatusRegistry.statuses_implementing(:absorb_damage)

      stages = StatusInterpreter.absorb_stages()
      guard_at = Enum.find_index(stages, &(&1 == :sc_autoguard))

      for earlier <- [:sc_kyrie, :sc_safetywall, :sc_pneuma, :sc_basilica, :sc_basilica_caster] do
        assert Enum.find_index(stages, &(&1 == earlier)) < guard_at
      end
    end
  end

  describe "begin_attempt/4 shield gate" do
    test "a player with a shield equipped may cast" do
      caster = player_with_shield()

      assert {:ok, _caster} = CrAutoguard.begin_attempt(caster, :self, 1, definition())
    end

    test "a player without a shield is refused" do
      caster = player_without_shield()

      assert {:error, :requires_shield} =
               CrAutoguard.begin_attempt(caster, :self, 1, definition())
    end

    test "a mob caster skips the shield gate" do
      assert {:ok, _caster} = CrAutoguard.begin_attempt(build_mob(9001), :self, 1, definition())
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

  describe "weapon-skill block through the combat pipeline" do
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
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)
      stub(UnitRegistry, :get_unit_info, fn :player, _id -> {:ok, %{stats: %{}}} end)

      :ok =
        StatusStorage.apply_status(:player, 5000, :sc_autoguard,
          val1: 10,
          state: %{block_chance: 100}
        )

      {:ok, caster_state: caster_state}
    end

    test "a weapon skill that misses never rolls Guard", %{caster_state: caster_state} do
      stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :miss end)
      reject(&Autoguard.absorb_damage/4)
      reject(&PlayerSession.apply_damage/4)

      assert :ok =
               SkillAttack.execute_skill_attack(caster_state, 5000,
                 skill_id: 253,
                 skill_level: 1,
                 skill_ratio: 100,
                 skip_range: true
               )
    end

    test "a weapon skill that connects rolls Guard on its calculated damage and lands for 0",
         %{caster_state: caster_state} do
      stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

      stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 60, is_critical: false}}
      end)

      expect(Autoguard, :absorb_damage, fn {:player, 5000}, entry, hit, context ->
        assert %{damage: 60, dmg_type: :physical, skill_id: 253} = hit
        Mimic.call_original(Autoguard, :absorb_damage, [{:player, 5000}, entry, hit, context])
      end)

      expect(PlayerSession, :apply_damage, fn _pid, 0, {:player, 1000}, _info -> :ok end)

      assert :ok =
               SkillAttack.execute_skill_attack(caster_state, 5000,
                 skill_id: 253,
                 skill_level: 1,
                 skill_ratio: 100,
                 skip_range: true
               )
    end

    test "a magic attack passes a sure Guard untouched", %{caster_state: caster_state} do
      stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 30, is_critical: false}}
      end)

      reject(&SpecialEffect.play/3)
      expect(PlayerSession, :apply_damage, fn _pid, 30, {:player, 1000}, _info -> :ok end)

      assert {:ok, {:player, 5000}} =
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

  defp entry(level),
    do: %StatusEntry{
      type: :sc_autoguard,
      val1: level,
      state: %{block_chance: Autoguard.block_chance(level)}
    }

  defp weapon_hit(damage, skill_id \\ nil),
    do: %{
      damage: damage,
      dmg_type: :physical,
      is_short: true,
      skill_id: skill_id,
      attacker: {:player, 1000}
    }

  defp devote(devotee_id, crusader_id) do
    crusader_pid = spawn(fn -> Process.sleep(:infinity) end)

    crusader = %PlayerState{
      character_id: crusader_id,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    }

    UnitRegistry.register_unit(:player, crusader_id, PlayerState, crusader, crusader_pid)
    SpatialIndex.add_player(devotee_id, 50, 50, "prontera")
    SpatialIndex.add_player(crusader_id, 51, 50, "prontera")

    link_id = make_ref()

    :ok =
      StatusStorage.apply_status(:player, devotee_id, :sc_devotion,
        state: %{peer: {:player, crusader_id}, link_id: link_id, range: 7}
      )

    :ok =
      StatusStorage.apply_status(:player, crusader_id, :sc_devoted_by,
        state: %{links: %{devotee_id => %{peer: {:player, devotee_id}, link_id: link_id}}}
      )
  end

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
      class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class([]),
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
