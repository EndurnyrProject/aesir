defmodule Aesir.ZoneServer.Mmo.Skills.AlHolylightTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AlHolylight
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_name(:al_holylight)
    definition
  end

  describe "catalog registration" do
    test "resolves by id, name, and active module" do
      assert {:ok, %{name: :al_holylight}} = Catalog.by_id(156)
      assert {:ok, %{id: 156}} = Catalog.by_name(:al_holylight)
      assert {:ok, AlHolylight} = Catalog.active_module_for(:al_holylight)
    end
  end

  describe "metadata" do
    test "matches the rAthena renewal table" do
      definition = definition()

      assert definition.max_level == 1
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.element == :holy
      assert definition.range == 9
      assert definition.cast_time == [800]
      assert definition.fixed_cast_time == [200]
      assert definition.sp_cost == [15]
    end
  end

  describe "cast/4" do
    test "issues a single holy magic hit at 125% MATK" do
      caster = caster()

      expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_id] == 156
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 125
        assert opts[:hit_count] == 1
        assert opts[:element] == :holy
        :ok
      end)

      assert {:ok, ^caster} = AlHolylight.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "propagates an attack error" do
      caster = caster()

      stub(Combat, :execute_magic_attack, fn ^caster, @target_id, _opts ->
        {:error, :target_out_of_range}
      end)

      assert {:error, :target_out_of_range} =
               AlHolylight.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end
end
