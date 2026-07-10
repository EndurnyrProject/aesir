defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.StatusAttackTest do
  @moduledoc """
  Unit coverage for the status-attack archetype: it must deal the magic damage
  through `ElementalNuke` and then inflict the params-driven status on the
  target with the caster recorded as source.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.ElementalNuke
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.StatusAttack
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :verify_on_exit!

  @caster_id 5001
  @target_id 42
  @map "prontera"
  @skill_id 179

  defp build_caster do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_CASTER",
      name: "Test Caster",
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

  test "deals magic damage then inflicts the params status with the caster as source" do
    caster = build_caster()
    test_pid = self()
    target = {:unit, :player, @target_id}

    expect(ElementalNuke, :apply, fn ^caster, ^target, params, 2 ->
      send(test_pid, {:nuke, params})
      :ok
    end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, status, opts ->
      send(test_pid, {:status, status, opts})
      :ok
    end)

    assert :ok =
             StatusAttack.apply(
               caster,
               target,
               %{
                 skill_id: @skill_id,
                 skill: "NPC_STUNATTACK",
                 element: :neutral,
                 status: :sc_stun
               },
               2
             )

    assert_received {:nuke, %{element: :neutral}}
    assert_received {:status, :sc_stun, opts}
    assert Keyword.get(opts, :caster_id) == @caster_id
    assert Keyword.get(opts, :source_id) == @caster_id
  end

  test "uses the status atom carried in params, not a hardcoded one" do
    caster = build_caster()
    test_pid = self()
    target = {:unit, :player, @target_id}

    stub(ElementalNuke, :apply, fn ^caster, ^target, _params, _level -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, status, _opts ->
      send(test_pid, {:status, status})
      :ok
    end)

    assert :ok =
             StatusAttack.apply(
               caster,
               target,
               %{skill_id: @skill_id, skill: "NPC_POISON", element: :poison, status: :sc_poison},
               1
             )

    assert_received {:status, :sc_poison}
  end

  test "propagates the nuke error and skips the status when the hit does not land" do
    caster = build_caster()
    target = {:unit, :player, @target_id}

    expect(ElementalNuke, :apply, fn ^caster, ^target, _params, _level ->
      {:error, :out_of_range}
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :out_of_range} =
             StatusAttack.apply(
               caster,
               target,
               %{
                 skill_id: @skill_id,
                 skill: "NPC_STUNATTACK",
                 element: :neutral,
                 status: :sc_stun
               },
               2
             )
  end

  test "rejects a non-player target shape without raising" do
    caster = build_caster()

    assert {:error, :invalid_target} =
             StatusAttack.apply(
               caster,
               {:unit, :mob, 999},
               %{
                 skill_id: @skill_id,
                 skill: "NPC_STUNATTACK",
                 element: :neutral,
                 status: :sc_stun
               },
               1
             )
  end
end
