defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcFireattackTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcFireattack
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :verify_on_exit!

  @caster_id 5001
  @target_id 2000
  @map "prontera"

  defp build_caster(overrides \\ %{}) do
    base = %{
      id: 1002,
      aegis_name: "TEST_CASTER",
      name: "Test Caster",
      level: 25,
      hp: 1000,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 10,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    mob_data = struct(MobDefinition, Map.merge(base, overrides))

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(@caster_id, mob_data, spawn_ref, @map, 100, 100)
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:npc_fireattack)
    definition
  end

  test "Catalog.active_module_for/1 resolves npc_fireattack" do
    assert {:ok, NpcFireattack} = Catalog.active_module_for(:npc_fireattack)
  end

  test "cast/4 delivers a flat 100% fire weapon hit against the target" do
    caster = build_caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == definition().id
      assert opts[:skill_level] == 3
      assert opts[:skill_ratio] == 100
      assert opts[:element] == :fire
      :ok
    end)

    assert {:ok, ^caster} = NpcFireattack.cast(caster, {:unit, @target_id}, 3, definition())
  end

  test "cast/4 keeps the ratio flat at 100% regardless of level" do
    caster = build_caster()

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 100
      :ok
    end)

    assert {:ok, ^caster} = NpcFireattack.cast(caster, {:unit, @target_id}, 10, definition())
  end

  test "cast/4 propagates a combat error without altering the caster" do
    caster = build_caster()

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :target_out_of_range}
    end)

    assert {:error, :target_out_of_range} =
             NpcFireattack.cast(caster, {:unit, @target_id}, 3, definition())
  end

  test "cast/4 widens a mob caster's attack range to skill_range for a chase/angry cast" do
    caster = build_caster(%{attack_range: 1, skill_range: 10})

    expect(Combat, :execute_skill_attack, fn combatant, @target_id, _opts ->
      assert combatant.mob_data.attack_range == 10
      :ok
    end)

    assert {:ok, ^caster} = NpcFireattack.cast(caster, {:unit, @target_id}, 3, definition())
  end

  test "cast/4 leaves attack_range alone when it already meets or exceeds skill_range" do
    caster = build_caster(%{attack_range: 12, skill_range: 10})

    expect(Combat, :execute_skill_attack, fn combatant, @target_id, _opts ->
      assert combatant.mob_data.attack_range == 12
      :ok
    end)

    assert {:ok, ^caster} = NpcFireattack.cast(caster, {:unit, @target_id}, 3, definition())
  end
end
