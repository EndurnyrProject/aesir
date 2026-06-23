defmodule Aesir.ZoneServer.Mmo.Skills.MgNapalmFireballTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.MgFireball
  alias Aesir.ZoneServer.Mmo.Skills.MgNapalmbeat
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp definition(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition
  end

  defp combatant(position) do
    Combatant.new!(%{
      unit_id: @target_id,
      unit_type: :mob,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 1,
        def: 1,
        hit: 1,
        flee: 1,
        perfect_dodge: 0,
        matk: 1,
        mdef: 1,
        soft_mdef: 1
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 1000,
      position: position
    })
  end

  describe "catalog registration" do
    test "by_id/1 resolves the skill ids" do
      assert {:ok, %{name: :mg_napalmbeat}} = Catalog.by_id(11)
      assert {:ok, %{name: :mg_fireball}} = Catalog.by_id(17)
    end

    test "by_name/1 resolves the skill atoms" do
      assert {:ok, %{id: 11}} = Catalog.by_name(:mg_napalmbeat)
      assert {:ok, %{id: 17}} = Catalog.by_name(:mg_fireball)
    end

    test "active_module_for/1 resolves the modules" do
      assert {:ok, MgNapalmbeat} = Catalog.active_module_for(:mg_napalmbeat)
      assert {:ok, MgFireball} = Catalog.active_module_for(:mg_fireball)
    end
  end

  describe "napalm beat metadata" do
    test "matches the rAthena renewal table" do
      definition = definition(:mg_napalmbeat)

      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.range == 9
      assert definition.element == :ghost
      assert definition.splash_radius == 1
      assert definition.cast_time == List.duplicate(400, 10)
      assert definition.fixed_cast_time == List.duplicate(100, 10)
      assert definition.after_cast_delay == List.duplicate(500, 10)
      assert definition.sp_cost == [9, 9, 9, 12, 12, 12, 15, 15, 15, 18]
    end
  end

  describe "napalm beat cast/4" do
    test "splits damage centered on the target cell" do
      caster = caster()
      definition = definition(:mg_napalmbeat)
      target = combatant({40, 50})

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

      expect(Combat, :execute_magic_splash, fn ^caster, {40, 50}, 1, opts ->
        assert opts[:skill_ratio] == 70 + 10 * 5
        assert opts[:element] == :ghost
        assert opts[:split] == true
        [@target_id]
      end)

      assert {:ok, ^caster} = MgNapalmbeat.cast(caster, {:unit, @target_id}, 5, definition)
    end

    test "propagates a resolve error" do
      caster = caster()
      definition = definition(:mg_napalmbeat)

      stub(Combat, :resolve_combatant, fn @target_id -> {:error, :not_found} end)
      reject(&Combat.execute_magic_splash/4)

      assert {:error, :not_found} =
               MgNapalmbeat.cast(caster, {:unit, @target_id}, 5, definition)
    end
  end

  describe "fire ball metadata" do
    test "matches the rAthena renewal table" do
      definition = definition(:mg_fireball)

      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.range == 9
      assert definition.element == :fire
      assert definition.splash_radius == 2
      assert definition.cast_time == List.duplicate(800, 10)
      assert definition.fixed_cast_time == List.duplicate(200, 10)
      assert definition.after_cast_delay == List.duplicate(700, 10)
      assert definition.sp_cost == List.duplicate(25, 10)
    end
  end

  describe "fire ball cast/4" do
    test "does not split damage centered on the target cell" do
      caster = caster()
      definition = definition(:mg_fireball)
      target = combatant({60, 70})

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

      expect(Combat, :execute_magic_splash, fn ^caster, {60, 70}, 2, opts ->
        assert opts[:skill_ratio] == 140 + 20 * 3
        assert opts[:element] == :fire
        assert opts[:split] == false
        [@target_id]
      end)

      assert {:ok, ^caster} = MgFireball.cast(caster, {:unit, @target_id}, 3, definition)
    end

    test "propagates a resolve error" do
      caster = caster()
      definition = definition(:mg_fireball)

      stub(Combat, :resolve_combatant, fn @target_id -> {:error, :not_found} end)
      reject(&Combat.execute_magic_splash/4)

      assert {:error, :not_found} =
               MgFireball.cast(caster, {:unit, @target_id}, 3, definition)
    end
  end
end
