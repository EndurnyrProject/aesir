defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcAllhealTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcAllheal
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 9001
  @target_id 2000

  describe "Catalog lookups" do
    test "by_id(687) resolves npc_allheal" do
      assert {:ok, definition} = Catalog.by_id(687)
      assert definition.name == :npc_allheal
    end

    test "by_name(:npc_allheal) resolves" do
      assert {:ok, definition} = Catalog.by_name(:npc_allheal)
      assert definition.id == 687
    end

    test "active_module_for/1 resolves npc_allheal" do
      assert {:ok, NpcAllheal} = Catalog.active_module_for(:npc_allheal)
    end
  end

  describe "cast/4" do
    setup do
      Aesir.TestEtsSetup.setup_ets_tables(%{})
      caster = mob(@caster_id, hp: 1000, max_hp: 1000)
      {:ok, definition} = Catalog.by_id(687)
      {:ok, caster: caster, definition: definition}
    end

    test "heals exactly the target's missing HP through Combat.apply_heal",
         %{caster: caster, definition: definition} do
      target = mob(@target_id, hp: 400, max_hp: 1000)
      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobState, target, self()}} end)

      expect(Combat, :apply_heal, fn :mob, @target_id, 600, @caster_id -> :ok end)

      assert {:ok, ^caster} = NpcAllheal.cast(caster, {:unit, @target_id}, 1, definition)
    end

    test "a target already at full HP heals for 0", %{caster: caster, definition: definition} do
      target = mob(@target_id, hp: 1000, max_hp: 1000)
      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobState, target, self()}} end)

      expect(Combat, :apply_heal, fn :mob, @target_id, 0, @caster_id -> :ok end)

      assert {:ok, ^caster} = NpcAllheal.cast(caster, {:unit, @target_id}, 1, definition)
    end

    test "an unresolvable target returns :target_gone and never calls apply_heal",
         %{caster: caster, definition: definition} do
      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
      reject(&Combat.apply_heal/4)

      assert {:error, :target_gone} = NpcAllheal.cast(caster, {:unit, @target_id}, 1, definition)
    end
  end

  defp mob(instance_id, opts) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: Keyword.fetch!(opts, :max_hp),
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    instance_id
    |> MobState.new(mob_data, spawn_ref, "prontera", 100, 100)
    |> Map.put(:hp, Keyword.fetch!(opts, :hp))
  end
end
