defmodule Aesir.ZoneServer.Mmo.Skills.AcShowerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AcShower

  setup :verify_on_exit!

  @target_id 5000

  defp caster, do: %{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_name(:ac_shower)
    definition
  end

  test "Catalog.by_id(47) resolves to :ac_shower" do
    assert {:ok, definition} = Catalog.by_id(47)
    assert definition.name == :ac_shower
  end

  test "Catalog.by_name(:ac_shower) resolves" do
    assert {:ok, definition} = Catalog.by_name(:ac_shower)
    assert definition.id == 47
  end

  test "Catalog.active_module_for/1 resolves ac_shower" do
    assert {:ok, AcShower} = Catalog.active_module_for(:ac_shower)
  end

  test "definition has requires_ammo: true" do
    assert definition().requires_ammo == true
  end

  test "definition has knockback: 2" do
    assert definition().knockback == 2
  end

  test "cast/4 at level <= 5 splashes radius 1 on the target cell and knocks each hit back 2" do
    caster = caster()

    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 1, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 100
      assert opts[:skip_crit] == true
      [101, 102]
    end)

    expect(Combat, :knockback, 2, fn :mob, target_id, 15, 25, 2 ->
      assert target_id in [101, 102]
      {:ok, {0, 0}}
    end)

    assert {:ok, ^caster} = AcShower.cast(caster, {:unit, @target_id}, 5, definition())
  end

  test "cast/4 at level >= 6 splashes radius 2" do
    caster = caster()

    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, _opts -> [] end)

    assert {:ok, ^caster} = AcShower.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "cast/4 propagates a target resolution error" do
    caster = caster()

    stub(Combat, :resolve_combatant, fn @target_id -> {:error, :target_not_found} end)

    assert {:error, :target_not_found} =
             AcShower.cast(caster, {:unit, @target_id}, 5, definition())
  end
end
