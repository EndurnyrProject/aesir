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

  test "cast/4 calls execute_skill_attack with hit_count: 2 and skill_ratio: 100" do
    caster = caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 100
      assert opts[:hit_count] == 2
      assert opts[:skip_crit] == true
      :ok
    end)

    assert {:ok, ^caster} = AcDouble.cast(caster, {:unit, @target_id}, 5, definition())
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
