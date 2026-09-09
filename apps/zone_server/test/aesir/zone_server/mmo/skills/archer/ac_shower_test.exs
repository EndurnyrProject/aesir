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

  test "skill_ratio/2 is stronger in renewal and weaker pre-renewal at every level" do
    assert AcShower.skill_ratio(:renewal, 1) == 160
    assert AcShower.skill_ratio(:renewal, 10) == 250
    assert AcShower.skill_ratio(:pre_renewal, 1) == 80
    assert AcShower.skill_ratio(:pre_renewal, 10) == 125
  end

  test "splash_radius/2 widens at level six in renewal but is always wide pre-renewal" do
    assert AcShower.splash_radius(:renewal, 1) == 1
    assert AcShower.splash_radius(:renewal, 5) == 1
    assert AcShower.splash_radius(:renewal, 6) == 2
    assert AcShower.splash_radius(:renewal, 10) == 2
    assert AcShower.splash_radius(:pre_renewal, 1) == 2
    assert AcShower.splash_radius(:pre_renewal, 10) == 2
  end

  test "the caster is locked for a tenth of a second after the cast only in renewal" do
    assert AcShower.definition(:renewal).after_cast_delay == List.duplicate(100, 10)
    assert AcShower.definition(:pre_renewal).after_cast_delay == []
  end

  test "the skill is bow-only in both modes" do
    assert AcShower.definition(:renewal).require_weapon == [:bow]
    assert AcShower.definition(:pre_renewal).require_weapon == [:bow]
  end

  @tag game_mode: :renewal
  test "level five passes target-centered mob-native and equipment blow through one splash" do
    caster = caster(%{{:add_skill_blow, 47} => 3})

    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 1, opts ->
      assert caster.stats.modifiers.equipment[{:add_skill_blow, 47}] == 3
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 200
      assert opts[:skip_crit] == true
      assert opts[:base_distance] == 2
      assert opts[:origin] == {15, 25}
      assert opts[:native_target_types] == [:mob]
      [101, 102]
    end)

    reject(&Combat.knockback/5)

    assert {:ok, ^caster} = AcShower.cast(caster, {:unit, @target_id}, 5, definition())
  end

  @tag game_mode: :pre_renewal
  test "level five splashes the wide radius at the classic ratio" do
    caster = caster(%{{:add_skill_blow, 47} => 3})

    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 2, opts ->
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
