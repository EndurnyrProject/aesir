defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.SelfBuffTest do
  @moduledoc """
  Unit coverage for the self-buff archetype: it must apply the params-driven
  status to the casting mob itself, with the caster recorded as its own
  source.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.SelfBuff
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :verify_on_exit!

  @caster_id 7001
  @map "prontera"

  defp build_caster do
    mob_data = %MobDefinition{
      id: 1003,
      aegis_name: "TEST_BUFFER",
      name: "Test Buffer",
      level: 30,
      hp: 1500,
      sp: 0,
      stats: %{str: 35, agi: 40, vit: 45, int: 25, dex: 30, luk: 20},
      atk: 55,
      matk: 40,
      def: 20,
      mdef: 15,
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
      mob: 1003,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 50, y: 50}
    }

    MobState.new(@caster_id, mob_data, spawn_ref, @map, 50, 50)
  end

  test "applies the params status to the caster itself, with itself as source" do
    caster = build_caster()
    test_pid = self()
    target = {:unit, :mob, @caster_id}

    expect(StatusInterpreter, :apply_status, fn :mob, @caster_id, status, opts ->
      send(test_pid, {:status, status, opts})
      :ok
    end)

    assert :ok =
             SelfBuff.apply(
               caster,
               target,
               %{skill_id: 391, skill: "NPC_AGIUP", status: :sc_increaseagi},
               3
             )

    assert_received {:status, :sc_increaseagi, opts}
    assert Keyword.get(opts, :caster_id) == @caster_id
    assert Keyword.get(opts, :source_id) == @caster_id
    assert Keyword.get(opts, :val1) == 3
    assert Keyword.get(opts, :val2) == 3
  end

  test "uses the status atom carried in params, not a hardcoded one" do
    caster = build_caster()
    target = {:unit, :mob, @caster_id}

    expect(StatusInterpreter, :apply_status, fn :mob, @caster_id, :sc_endure, _opts -> :ok end)

    assert :ok =
             SelfBuff.apply(
               caster,
               target,
               %{skill_id: 8, skill: "SM_ENDURE", status: :sc_endure},
               5
             )
  end

  test "propagates the interpreter error unchanged" do
    caster = build_caster()
    target = {:unit, :mob, @caster_id}

    expect(StatusInterpreter, :apply_status, fn :mob, @caster_id, :sc_increaseagi, _opts ->
      {:error, :status_immune}
    end)

    assert {:error, :status_immune} =
             SelfBuff.apply(
               caster,
               target,
               %{skill_id: 391, skill: "NPC_AGIUP", status: :sc_increaseagi},
               1
             )
  end

  test "rejects a non-self target shape without raising" do
    caster = build_caster()

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :invalid_target} =
             SelfBuff.apply(
               caster,
               {:unit, :player, 999},
               %{skill_id: 391, skill: "NPC_AGIUP", status: :sc_increaseagi},
               1
             )
  end
end
