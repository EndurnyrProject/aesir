defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcShowerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Archer.AcShower
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :verify_on_exit!

  @target_id 5000

  defp caster(equipment \\ %{}) do
    %PlayerState{
      character_id: 1_000,
      stats: %Stats{modifiers: %Modifiers{equipment: equipment}}
    }
  end

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

  test "level five passes target-centered mob-native and equipment blow through one splash" do
    caster = caster(%{{:add_skill_blow, 47} => 3})

    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 1, opts ->
      assert caster.stats.modifiers.equipment[{:add_skill_blow, 47}] == 3
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 100
      assert opts[:skip_crit] == true
      assert opts[:base_distance] == 2
      assert opts[:origin] == {15, 25}
      assert opts[:native_target_types] == [:mob]
      [101, 102]
    end)

    reject(&Combat.knockback/5)

    assert {:ok, ^caster} = AcShower.cast(caster, {:unit, @target_id}, 5, definition())
  end

  test "cast/4 at level >= 6 splashes radius 2" do
    caster = caster()

    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
      assert opts[:base_distance] == 2
      []
    end)

    reject(&Combat.knockback/5)

    assert {:ok, ^caster} = AcShower.cast(caster, {:unit, @target_id}, 6, definition())
  end

  test "cast/4 propagates a target resolution error" do
    caster = caster()

    reject(&Combat.execute_splash_attack/4)
    reject(&Combat.knockback/5)
    stub(Combat, :resolve_combatant, fn @target_id -> {:error, :target_not_found} end)

    assert {:error, :target_not_found} =
             AcShower.cast(caster, {:unit, @target_id}, 5, definition())
  end
end
