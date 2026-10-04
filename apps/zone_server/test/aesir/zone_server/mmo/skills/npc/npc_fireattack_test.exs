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

  for {module, element} <- [
        {NpcFireattack, :fire},
        {Aesir.ZoneServer.Mmo.Skills.Npc.NpcWaterattack, :water},
        {Aesir.ZoneServer.Mmo.Skills.Npc.NpcWindattack, :wind},
        {Aesir.ZoneServer.Mmo.Skills.Npc.NpcGroundattack, :earth},
        {Aesir.ZoneServer.Mmo.Skills.Npc.NpcPoisonattack, :poison},
        {Aesir.ZoneServer.Mmo.Skills.Npc.NpcHolyattack, :holy},
        {Aesir.ZoneServer.Mmo.Skills.Npc.NpcDarknessattack, :shadow},
        {Aesir.ZoneServer.Mmo.Skills.Npc.NpcUndeadattack, :undead}
      ] do
    @module module
    @element element

    test "#{inspect(module)} strikes for 100% ATK per level in its element with a 20% hit bonus" do
      caster = build_caster()
      definition = @module.definition()

      expect(Combat, :execute_skill_attack, fn passed, @target_id, opts ->
        assert passed.mob_data.attack_range == 10
        assert opts[:skill_id] == definition.id
        assert opts[:skill_ratio] == 300
        assert opts[:element] == @element
        assert opts[:hit_rate_bonus_pct] == 20
        :ok
      end)

      assert {:ok, ^caster} = @module.cast(caster, {:unit, @target_id}, 3, definition)
    end
  end
end
