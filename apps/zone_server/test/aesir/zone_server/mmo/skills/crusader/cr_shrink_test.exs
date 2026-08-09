defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShrinkTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrShrink
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Shrink
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpecialEffect

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  @skill_id 1002
  @shield_nameid 2101
  @left_hand 0x20

  describe "catalog" do
    test "resolves CR_SHRINK as a self-target quest toggle" do
      {:ok, definition} = Catalog.by_id(@skill_id)

      assert definition.name == :cr_shrink
      assert definition.max_level == 1
      assert definition.target_type == :self
      assert definition.sp_cost == [100]
      assert definition.quest_skill == true
      assert definition.quest_owner_job == :crusader
    end

    test "resolves the active module by name" do
      assert {:ok, CrShrink} = Catalog.active_module_for(:cr_shrink)
    end
  end

  describe "validate/4 shield gate" do
    test "a player with a shield equipped may cast" do
      assert :ok = CrShrink.validate(player_with_shield(), :self, 1, definition())
    end

    test "a player without a shield is refused" do
      assert {:error, :requires_shield} =
               CrShrink.validate(player_without_shield(), :self, 1, definition())
    end

    test "a mob caster skips the shield gate" do
      assert :ok = CrShrink.validate(build_mob(9001), :self, 1, definition())
    end
  end

  describe "cast/4 toggle" do
    test "casting applies the status" do
      caster = %PlayerState{character_id: 1000}

      expect(StatusInterpreter, :toggle_status, fn :player, 1000, :sc_shrink, params ->
        assert Keyword.fetch!(params, :val1) == 1
        {:ok, :applied}
      end)

      assert {:ok, ^caster} = CrShrink.cast(caster, :self, 1, definition())
    end

    test "re-casting toggles the status off" do
      caster = %PlayerState{character_id: 1000}

      expect(StatusInterpreter, :toggle_status, fn :player, 1000, :sc_shrink, _params ->
        {:ok, :removed}
      end)

      assert {:ok, ^caster} = CrShrink.cast(caster, :self, 1, definition())
    end

    test "a mob caster toggles on itself" do
      caster = build_mob(9002)

      expect(StatusInterpreter, :toggle_status, fn :mob, 9002, :sc_shrink, _params ->
        {:ok, :applied}
      end)

      assert {:ok, ^caster} = CrShrink.cast(caster, :self, 1, definition())
    end
  end

  describe "maybe_stun_attacker/2 proc" do
    test "stuns the attacker on a successful roll while the guarder holds Shrink" do
      :ok = StatusStorage.apply_status(:player, 3000, :sc_shrink, val1: 1)
      seed_for_roll(50)

      expect(StatusInterpreter, :apply_status, fn :mob, 7000, :sc_stun, params ->
        assert Keyword.fetch!(params, :duration) == 5_000
        assert Keyword.fetch!(params, :caster_id) == 3000
        assert Keyword.fetch!(params, :source_type) == :player
        :ok
      end)

      assert :ok = Shrink.maybe_stun_attacker({:player, 3000}, {:mob, 7000})
    end

    test "does not stun when the roll exceeds the 50% chance" do
      :ok = StatusStorage.apply_status(:player, 3001, :sc_shrink, val1: 1)
      seed_for_roll(51)
      reject(&StatusInterpreter.apply_status/4)

      assert :ok = Shrink.maybe_stun_attacker({:player, 3001}, {:mob, 7001})
    end

    test "does nothing when the guarder does not hold Shrink" do
      seed_for_roll(1)
      reject(&StatusInterpreter.apply_status/4)

      assert :ok = Shrink.maybe_stun_attacker({:player, 3002}, {:mob, 7002})
    end
  end

  describe "Guard block integration" do
    test "a blocked hit stuns the attacker when the guarder also holds Shrink" do
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)
      :ok = StatusStorage.apply_status(:player, 4000, :sc_shrink, val1: 1)

      seed_block_then_stun()

      expect(StatusInterpreter, :apply_status, fn :mob, 7100, :sc_stun, _params -> :ok end)

      assert {:intercept, :blocked} =
               Autoguard.before_weapon_hit(
                 {:player, 4000},
                 %StatusEntry{type: :sc_autoguard, val1: 10},
                 %{attacker: {:mob, 7100}},
                 %{}
               )
    end

    test "a blocked hit without Shrink leaves the attacker unharmed" do
      stub(SpecialEffect, :play, fn _unit, _effect, _target -> :ok end)
      seed_for_roll(1)
      reject(&StatusInterpreter.apply_status/4)

      assert {:intercept, :blocked} =
               Autoguard.before_weapon_hit(
                 {:player, 4001},
                 %StatusEntry{type: :sc_autoguard, val1: 10},
                 %{attacker: {:mob, 7101}},
                 %{}
               )
    end
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(@skill_id)
    definition
  end

  # Seeds `:rand` so the next `:rand.uniform(100)` returns exactly `target`.
  defp seed_for_roll(target) do
    seed =
      Enum.find(1..50_000, fn candidate ->
        :rand.seed(:exsss, {1, 1, candidate})
        :rand.uniform(100) == target
      end)

    :rand.seed(:exsss, {1, 1, seed})
  end

  # Seeds `:rand` so the block roll succeeds (<= 30 at level 10) and the
  # following Shrink roll also succeeds (<= 50).
  defp seed_block_then_stun do
    seed =
      Enum.find(1..500_000, fn candidate ->
        :rand.seed(:exsss, {1, 1, candidate})
        :rand.uniform(100) <= 30 and :rand.uniform(100) <= 50
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
