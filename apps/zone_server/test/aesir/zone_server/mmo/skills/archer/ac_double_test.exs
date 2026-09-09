defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcDoubleTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Archer.AcDouble

  setup :verify_on_exit!

  @target_id 5000

  defp caster, do: %{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_name(:ac_double)
    definition
  end

  test "Catalog.by_id(46) resolves to :ac_double" do
    assert {:ok, definition} = Catalog.by_id(46)
    assert definition.name == :ac_double
  end

  test "Catalog.by_name(:ac_double) resolves" do
    assert {:ok, definition} = Catalog.by_name(:ac_double)
    assert definition.id == 46
  end

  test "Catalog.active_module_for/1 resolves ac_double" do
    assert {:ok, AcDouble} = Catalog.active_module_for(:ac_double)
  end

  test "definition has requires_ammo: true" do
    assert definition().requires_ammo == true
  end

  test "definition has hit_count: 2" do
    assert definition().hit_count == 2
  end

  test "cast/4 calls execute_skill_attack with hit_count: 2 and the level-scaled ratio" do
    caster = caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 140
      assert opts[:hit_count] == 2
      assert opts[:skip_crit] == true
      :ok
    end)

    assert {:ok, ^caster} = AcDouble.cast(caster, {:unit, @target_id}, 5, definition())
  end

  test "skill_ratio/1 is 100 percent per hit at level 1, rising 10 points per level" do
    assert AcDouble.skill_ratio(1) == 100
    assert AcDouble.skill_ratio(2) == 110
    assert AcDouble.skill_ratio(10) == 190
  end

  test "the caster is locked for a tenth of a second after the cast only in renewal" do
    assert AcDouble.definition(:renewal).after_cast_delay == List.duplicate(100, 10)
    assert AcDouble.definition(:pre_renewal).after_cast_delay == []
  end

  test "the skill is bow-only in both modes" do
    assert AcDouble.definition(:renewal).require_weapon == [:bow]
    assert AcDouble.definition(:pre_renewal).require_weapon == [:bow]
  end

  test "cast/4 propagates an attack error" do
    caster = caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    assert {:error, :target_out_of_range} =
             AcDouble.cast(caster, {:unit, @target_id}, 5, definition())
  end
end
