defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldchargeTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldcharge
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 5000
  @guard 2101
  @sword 1101
  @right_hand 2
  @left_hand 32

  defp definition do
    {:ok, definition} = Catalog.by_id(250)
    definition
  end

  defp build_caster(equipped_items) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{base_level: 50, job_level: 40, learned_skills: %{}},
      equipment: Stats.equipment_from_inventory(equipped_items)
    }

    %PlayerState{character_id: 1000, x: 10, y: 20, stats: stats}
  end

  defp caster_with_shield do
    build_caster([
      %InventoryItem{nameid: @sword, amount: 1, equip: @right_hand, identify: 1},
      %InventoryItem{nameid: @guard, amount: 1, equip: @left_hand, identify: 1}
    ])
  end

  defp caster_without_shield do
    build_caster([
      %InventoryItem{nameid: @sword, amount: 1, equip: @right_hand, identify: 1}
    ])
  end

  defp mob_caster do
    %MobState{
      instance_id: 1,
      mob_id: 1_002,
      mob_data: %{element: {:neutral, 1}, race: :formless, modes: []},
      spawn_ref: nil,
      x: 10,
      y: 20,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 10,
      max_sp: 10,
      spawned_at: 0
    }
  end

  test "Catalog.by_id/1 resolves CR_SHIELDCHARGE" do
    assert definition().name == :cr_shieldcharge
    assert definition().max_level == 5
    assert definition().target_type == :target_enemy
    assert definition().damage_type == :damage
    assert definition().range == 3
    assert definition().damage_base == :shield
    assert definition().sp_cost == [10, 10, 10, 10, 10]
  end

  test "Catalog.active_module_for/1 resolves cr_shieldcharge" do
    assert {:ok, CrShieldcharge} = Catalog.active_module_for(:cr_shieldcharge)
  end

  describe "validate/4" do
    test "ok with a shield equipped" do
      assert CrShieldcharge.validate(caster_with_shield(), {:unit, @target_id}, 1, definition()) ==
               :ok
    end

    test "refused without a shield equipped" do
      assert CrShieldcharge.validate(
               caster_without_shield(),
               {:unit, @target_id},
               1,
               definition()
             ) == {:error, :requires_shield}
    end

    test "mob casters skip the shield gate" do
      assert CrShieldcharge.validate(mob_caster(), {:unit, @target_id}, 1, definition()) == :ok
    end
  end

  describe "cast/4 damage ratio" do
    test "level 1 uses ratio 120 on the shield base" do
      caster = caster_with_shield()

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_id] == definition().id
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 120
        assert opts[:damage_base] == :shield
        assert opts[:skip_crit] == true
        assert opts[:report_hit] == true
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "level 3 uses ratio 160" do
      caster = caster_with_shield()

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 160
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 3, definition())
    end

    test "level 5 uses ratio 200" do
      caster = caster_with_shield()

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == 200
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 5, definition())
    end

    test "propagates an attack error without rolling riders" do
      caster = caster_with_shield()

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:error, :target_out_of_range}
      end)

      reject(&Combat.knockback/5)
      reject(&StatusInterpreter.apply_status/4)

      assert {:error, :target_out_of_range} =
               CrShieldcharge.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end

  describe "cast/4 riders" do
    test "does not knock back or stun when the attack misses" do
      caster = caster_with_shield()

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:ok, %{hit?: false}}
      end)

      reject(&Combat.knockback/5)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 5, definition())
    end

    test "passes native and equipment blow through one canonical attack request" do
      caster = caster_with_shield()
      caster = put_in(caster.stats.modifiers.equipment, %{{:add_skill_blow, 250} => 2})

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert caster.stats.modifiers.equipment[{:add_skill_blow, 250}] == 2
        assert opts[:base_distance] == 7
        assert opts[:origin] == {10, 20}
        assert opts[:native_target_types] == [:player, :mob, :homunculus]
        {:ok, %{hit?: true}}
      end)

      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
      stub(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, _params -> :ok end)
      reject(&Combat.knockback/5)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 3, definition())
    end

    test "applies sc_stun for 4500ms when the roll succeeds on a connecting hit" do
      # Seed {1,1,185} yields :rand.uniform(100) == 1, at or below the 30% (15+5x3) chance.
      :rand.seed(:exsss, {1, 1, 185})
      caster = caster_with_shield()

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        send(self(), :combined_blow_requested)
        {:ok, %{hit?: true}}
      end)

      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
      reject(&Combat.knockback/5)

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stun, params ->
        assert_received :combined_blow_requested
        assert params[:duration] == 4_500
        :ok
      end)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 3, definition())
    end

    test "does not apply stun on a connecting hit when the roll fails" do
      # Seed {1,1,2} yields :rand.uniform(100) == 98, above the 20% (15+5x1) chance.
      :rand.seed(:exsss, {1, 1, 2})
      caster = caster_with_shield()

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:base_distance] == 5
        {:ok, %{hit?: true}}
      end)

      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
      reject(&Combat.knockback/5)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end

  describe "mob_cast fallback" do
    test "a mob caster deals damage through the shield-base fallback (plain batk)" do
      caster = mob_caster()

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert opts[:damage_base] == :shield
        assert opts[:origin] == {10, 20}
        {:ok, %{hit?: false}}
      end)

      assert {:ok, ^caster} = CrShieldcharge.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end
end
