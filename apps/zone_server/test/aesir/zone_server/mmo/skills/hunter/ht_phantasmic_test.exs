defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtPhantasmicTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtPhantasmic
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :verify_on_exit!

  @target_id 2000

  defp caster(equipment \\ %Equipment{right_hand: 1_701}) do
    %PlayerState{character_id: 1000, x: 50, y: 60, stats: %Stats{equipment: equipment}}
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:ht_phantasmic)
    definition
  end

  describe "catalog registration & metadata" do
    test "publishes a grant-only Hunter quest skill matching the rAthena table" do
      assert {:ok, %{name: :ht_phantasmic}} = Catalog.by_id(1009)
      assert {:ok, HtPhantasmic} = Catalog.active_module_for(:ht_phantasmic)

      d = definition()
      assert d.max_level == 1
      assert d.target_type == :target_enemy
      assert d.damage_type == :damage
      assert d.damage_kind == :weapon
      assert d.element == :wind
      assert d.range == -1
      assert d.knockback == 3
      assert d.sp_cost == [50]
      assert d.item_cost == []
      assert d.requires_ammo == false
      assert d.quest_skill == true
      assert d.quest_owner_job == :hunter
      assert {:ok, ^d} = Catalog.by_id(1009)
    end
  end

  describe "validate/4 (equipment)" do
    test "requires an equipped bow, rejecting every other weapon" do
      stub(Stats, :weapon_type, fn
        %Equipment{right_hand: 1_701} -> :bow
        _equipment -> :dagger
      end)

      assert :ok = HtPhantasmic.validate(caster(), {:unit, @target_id}, 1, definition())

      unarmed = caster(%Equipment{right_hand: nil})

      assert {:error, :bow_not_equipped} =
               HtPhantasmic.validate(unarmed, {:unit, @target_id}, 1, definition())
    end

    test "does not require an equipped arrow" do
      stub(Stats, :weapon_type, fn _equipment -> :bow end)

      no_arrow = caster(%Equipment{right_hand: 1_701, ammo: nil})

      assert :ok = HtPhantasmic.validate(no_arrow, {:unit, @target_id}, 1, definition())
    end
  end

  describe "cast/4" do
    test "forwards survival-gated native and equipment blow through the ordinary contract" do
      caster = caster()
      caster = put_in(caster.stats.modifiers.equipment, %{{:add_skill_blow, 1009} => 2})

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert caster.stats.modifiers.equipment[{:add_skill_blow, 1009}] == 2
        assert opts[:skill_id] == 1009
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 500
        assert opts[:element] == :wind
        assert opts[:hit_count] == 1
        assert opts[:skip_crit] == true
        refute Keyword.has_key?(opts, :report_hit)
        assert opts[:base_distance] == 3
        assert opts[:origin] == {50, 60}
        assert opts[:native_target_types] == [:mob]
        assert opts[:native_requires_survival] == true
        :ok
      end)

      reject(&Combat.knockback/5)

      assert {:ok, ^caster} = HtPhantasmic.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "propagates an attack error" do
      caster = caster()

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:error, :target_out_of_range}
      end)

      assert {:error, :target_out_of_range} =
               HtPhantasmic.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end
end
