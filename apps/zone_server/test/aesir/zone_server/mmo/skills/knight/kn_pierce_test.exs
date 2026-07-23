defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnPierceTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnPierce
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  @target_id 4000
  @one_handed_spear 1400
  @two_handed_spear 1410
  @sword 1101
  @right_hand 2
  @both_hand 3

  defp definition do
    {:ok, definition} = Catalog.by_name(:kn_pierce)
    definition
  end

  defp build_caster(weapon_nameid, equip_slot \\ @right_hand) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{base_level: 50, job_level: 30, learned_skills: %{}},
      equipment:
        Stats.equipment_from_inventory([
          %InventoryItem{nameid: weapon_nameid, amount: 1, equip: equip_slot, identify: 1}
        ])
    }

    %PlayerState{character_id: 1000, stats: stats}
  end

  describe "catalog registration" do
    test "Catalog.by_id(56) resolves to :kn_pierce" do
      assert {:ok, definition} = Catalog.by_id(56)
      assert definition.name == :kn_pierce
    end

    test "Catalog.by_name(:kn_pierce) resolves" do
      assert {:ok, definition} = Catalog.by_name(:kn_pierce)
      assert definition.id == 56
    end

    test "Catalog.active_module_for/1 resolves kn_pierce" do
      assert {:ok, KnPierce} = Catalog.active_module_for(:kn_pierce)
    end

    test "definition carries max_level, target/damage type, range, and flat SP cost" do
      definition = definition()
      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.range == -1
      assert definition.sp_cost == List.duplicate(7, 10)
    end
  end

  describe "validate/4 (spear requirement)" do
    test "a one-handed spear passes" do
      caster = build_caster(@one_handed_spear)
      assert :ok = KnPierce.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a two-handed spear passes" do
      caster = build_caster(@two_handed_spear, @both_hand)
      assert :ok = KnPierce.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a non-spear weapon fails with :requires_spear" do
      caster = build_caster(@sword)

      assert {:error, :requires_spear} =
               KnPierce.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "bare-fixture player state with no stats is tolerated" do
      assert :ok =
               KnPierce.validate(
                 %PlayerState{character_id: 1000},
                 {:unit, @target_id},
                 1,
                 definition()
               )
    end

    test "a non-player caster (mob) bypasses the weapon gate" do
      assert :ok = KnPierce.validate(%{instance_id: 1}, {:unit, @target_id}, 1, definition())
    end
  end

  describe "cast/4 (size-scaled hit count and per-cast accuracy)" do
    test "a small target takes 1 hit" do
      caster = build_caster(@one_handed_spear)
      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{size: :small}} end)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:hit_count] == 1
        :ok
      end)

      assert {:ok, ^caster} = KnPierce.cast(caster, {:unit, @target_id}, 3, definition())
    end

    test "a medium target takes 2 hits" do
      caster = build_caster(@one_handed_spear)
      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{size: :medium}} end)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:hit_count] == 2
        :ok
      end)

      assert {:ok, ^caster} = KnPierce.cast(caster, {:unit, @target_id}, 3, definition())
    end

    test "a large target takes 3 hits" do
      caster = build_caster(@one_handed_spear)
      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{size: :large}} end)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:hit_count] == 3
        :ok
      end)

      assert {:ok, ^caster} = KnPierce.cast(caster, {:unit, @target_id}, 3, definition())
    end

    test "the skill ratio is 100 + 10 per level and the hit rate bonus is 5% per level" do
      caster = build_caster(@one_handed_spear)
      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{size: :medium}} end)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_id] == definition().id
        assert opts[:skill_level] == 7
        assert opts[:skill_ratio] == 100 + 10 * 7
        assert opts[:hit_rate_bonus_pct] == 5 * 7
        assert opts[:skip_crit] == true
        :ok
      end)

      assert {:ok, ^caster} = KnPierce.cast(caster, {:unit, @target_id}, 7, definition())
    end

    test "propagates a target resolution error" do
      caster = build_caster(@one_handed_spear)
      stub(Combat, :resolve_combatant, fn @target_id -> {:error, :target_not_found} end)
      reject(&Combat.execute_skill_attack/3)

      assert {:error, :target_not_found} =
               KnPierce.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "propagates an attack error" do
      caster = build_caster(@one_handed_spear)
      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{size: :small}} end)

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:error, :target_out_of_range}
      end)

      assert {:error, :target_out_of_range} =
               KnPierce.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end
end
