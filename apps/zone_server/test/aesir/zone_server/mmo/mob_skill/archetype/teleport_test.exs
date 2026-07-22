defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.TeleportTest do
  @moduledoc """
  The teleport archetype is a thin shim: it self-casts `{:movement, :teleport}`
  to the caster's own `MobSession` (the reposition itself is covered end-to-end by
  `MobSessionTeleportTest`) and returns `:ok`. A caster with no live process is
  a clean `{:error, :no_process}`.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.MobSkill.Archetype.Teleport
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @caster_id 5001

  defp build_caster(overrides) do
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

    state = MobState.new(@caster_id, mob_data, spawn_ref, "prontera", 100, 100)
    struct(state, Map.new(overrides))
  end

  test "self-casts the teleport to the caster's process and returns :ok" do
    caster = build_caster(%{process_pid: self()})

    assert :ok = Teleport.apply(caster, {:unit, :mob, @caster_id}, %{}, 1)

    assert_received {:"$gen_cast", {:movement, :teleport}}
  end

  test "returns an error when the caster has no live process" do
    caster = build_caster(%{process_pid: nil})

    assert {:error, :no_process} = Teleport.apply(caster, {:unit, :mob, @caster_id}, %{}, 1)
  end
end
