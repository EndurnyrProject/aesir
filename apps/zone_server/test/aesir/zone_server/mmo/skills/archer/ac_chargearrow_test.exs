defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcChargearrowTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Archer.AcChargearrow
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :verify_on_exit!

  @target_id 2000

  defp caster(equipment \\ %{}) do
    %PlayerState{
      character_id: 1000,
      x: 50,
      y: 60,
      stats: %Stats{modifiers: %Modifiers{equipment: equipment}}
    }
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:ac_chargearrow)
    definition
  end

  describe "catalog registration & metadata" do
    test "matches the rAthena table" do
      assert {:ok, %{name: :ac_chargearrow}} = Catalog.by_id(148)
      assert {:ok, AcChargearrow} = Catalog.active_module_for(:ac_chargearrow)

      d = definition()
      assert d.max_level == 1
      assert d.target_type == :target_enemy
      assert d.damage_type == :damage
      assert d.damage_kind == :weapon
      assert d.range == -1
      assert d.knockback == 6
      assert d.requires_ammo == true
      assert d.cast_time == [400]
      assert d.fixed_cast_time == [800]
      assert d.sp_cost == [15]
    end
  end

  describe "cast/4" do
    test "forwards native and equipment blow through the ordinary attack contract" do
      caster = caster(%{{:add_skill_blow, 148} => 2})

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
        assert caster.stats.modifiers.equipment[{:add_skill_blow, 148}] == 2
        assert opts[:skill_id] == 148
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 150
        assert opts[:hit_count] == 1
        assert opts[:skip_crit] == true
        refute Keyword.has_key?(opts, :report_hit)
        assert opts[:base_distance] == 6
        assert opts[:origin] == {50, 60}
        assert opts[:native_target_types] == [:mob]
        :ok
      end)

      reject(&Combat.knockback/5)

      assert {:ok, ^caster} = AcChargearrow.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "propagates an attack error" do
      caster = caster()

      expect(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:error, :target_out_of_range}
      end)

      assert {:error, :target_out_of_range} =
               AcChargearrow.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end
end
