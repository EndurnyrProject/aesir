defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrHolycrossTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrHolycross
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 5000
  @two_handed_spear 1410
  @sword 1101
  @right_hand 2
  @both_hand 3

  defp definition do
    {:ok, definition} = Catalog.by_id(253)
    definition
  end

  defp build_caster(weapon_nameid, equip_slot \\ @right_hand) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{base_level: 50, job_level: 40, learned_skills: %{}},
      equipment:
        Stats.equipment_from_inventory([
          %InventoryItem{nameid: weapon_nameid, amount: 1, equip: equip_slot, identify: 1}
        ])
    }

    %PlayerState{character_id: 1000, stats: stats}
  end

  test "Catalog.by_id/1 resolves CR_HOLYCROSS" do
    assert definition().name == :cr_holycross
    assert definition().max_level == 10
    assert definition().target_type == :target_enemy
    assert definition().damage_type == :damage
    assert definition().element == :holy
    assert definition().range == -1
    assert definition().sp_cost == Enum.to_list(11..20)
  end

  test "Catalog.active_module_for/1 resolves cr_holycross" do
    assert {:ok, CrHolycross} = Catalog.active_module_for(:cr_holycross)
  end

  describe "cast/4 damage ratio and element" do
    test "level 1 without a two-handed spear uses ratio 35" do
      caster = build_caster(@sword)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_id] == definition().id
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 35
        assert opts[:element] == :holy
        assert opts[:hit_count] == 2
        assert opts[:skip_crit] == true
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "level 5 without a two-handed spear uses ratio 175" do
      caster = build_caster(@sword)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 175
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 5, definition())
    end

    test "level 10 without a two-handed spear uses ratio 350" do
      caster = build_caster(@sword)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 350
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 10, definition())
    end

    test "level 1 with a two-handed spear doubles the ratio to 70" do
      caster = build_caster(@two_handed_spear, @both_hand)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 70
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "level 5 with a two-handed spear doubles the ratio to 350" do
      caster = build_caster(@two_handed_spear, @both_hand)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 350
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 5, definition())
    end

    test "level 10 with a two-handed spear doubles the ratio to 700" do
      caster = build_caster(@two_handed_spear, @both_hand)

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 700
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 10, definition())
    end

    test "a bare-fixture player state with no stats falls back to the base ratio" do
      caster = %PlayerState{character_id: 1000}

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 35
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "a mob caster bypasses the weapon check and uses the base ratio" do
      caster = %{instance_id: 1}

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 35
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end

  describe "cast/4 blind rider" do
    test "does not roll blind when the attack misses" do
      caster = build_caster(@sword)

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:ok, %{hit?: false}}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 5, definition())
    end

    test "applies sc_blind for 18000ms when the roll succeeds on a connecting hit" do
      # Seed {1,1,185} yields :rand.uniform(100) == 1, at or below the 15% (3x5) chance.
      :rand.seed(:exsss, {1, 1, 185})
      caster = build_caster(@sword)

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:ok, %{hit?: true}}
      end)

      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_blind, params ->
        assert params[:duration] == 18_000
        :ok
      end)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 5, definition())
    end

    test "does not apply blind on a connecting hit when the roll fails" do
      # Seed {1,1,1} yields :rand.uniform(100) == 8, above the 3% (3x1) chance.
      :rand.seed(:exsss, {1, 1, 1})
      caster = build_caster(@sword)

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:ok, %{hit?: true}}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = CrHolycross.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "propagates an attack error without rolling blind" do
      caster = build_caster(@sword)

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:error, :target_out_of_range}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:error, :target_out_of_range} =
               CrHolycross.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end
end
