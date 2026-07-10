defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.HealTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.Heal
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 5001
  @map "prontera"

  defp build_caster do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_HEALER",
      name: "Test Healer",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
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

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(@caster_id, mob_data, spawn_ref, @map, 100, 100)
  end

  test "self-heal resolves the target pid and heals a positive amount" do
    caster = build_caster()
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    test_pid = self()

    stub(UnitRegistry, :get_unit, fn :mob, @caster_id ->
      {:ok, {MobSession, %{}, target_pid}}
    end)

    stub(MobSession, :heal, fn ^target_pid, amount ->
      send(test_pid, {:healed, amount})
      :ok
    end)

    assert :ok = Heal.apply(caster, {:unit, :mob, @caster_id}, %{}, 3)

    assert_received {:healed, amount}
    assert amount > 0
  end

  test "returns {:error, :target_gone} when the mob is not in the registry" do
    caster = build_caster()

    stub(UnitRegistry, :get_unit, fn :mob, 9999 -> {:error, :not_found} end)

    assert {:error, :target_gone} = Heal.apply(caster, {:unit, :mob, 9999}, %{}, 3)
  end

  test "returns {:error, :invalid_target} for a non-mob target shape" do
    caster = build_caster()

    assert {:error, :invalid_target} =
             Heal.apply(caster, {:unit, :player, 42}, %{}, 3)
  end
end
