defmodule Aesir.ZoneServer.Mmo.Skill.CasterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Requirement
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  test "resolves each caster state to its adapter" do
    assert Caster.for(player()) == Caster.Player
    assert Caster.for(homunculus()) == Caster.Homunculus
    assert Caster.for(mob()) == Caster.Mob
  end

  test "rejects unknown caster structs clearly" do
    assert_raise ArgumentError, ~r/unsupported skill caster.*URI/, fn ->
      Caster.for(%URI{})
    end
  end

  test "player adapter exposes identity, geometry, range, and facilities" do
    state = player()

    assert Caster.Player.kind() == :player
    assert Caster.Player.provides() == Requirement.all()
    assert Enum.all?(Caster.Player.provides(), &Requirement.valid?/1)
    assert Caster.Player.id(state) == 101
    assert Caster.Player.unit_type(state) == :player
    assert Caster.Player.position(state) == {"prontera", 10, 20}
    assert Caster.Player.attack_range(state) == 1
    assert Caster.Player.broadcast_source(state) == 101
  end

  test "homunculus adapter exposes identity, geometry, range, and facilities" do
    state = homunculus()

    assert Caster.Homunculus.kind() == :homunculus
    assert Caster.Homunculus.provides() == [:homunculus_state]
    assert Enum.all?(Caster.Homunculus.provides(), &Requirement.valid?/1)
    assert Caster.Homunculus.id(state) == 301
    assert Caster.Homunculus.unit_type(state) == :homunculus
    assert Caster.Homunculus.position(state) == {"prontera", 11, 21}
    assert Caster.Homunculus.attack_range(state) == 3
    assert Caster.Homunculus.broadcast_source(state) == {:homunculus, 301}
  end

  test "mob adapter exposes identity, geometry, range, and facilities" do
    state = mob()

    assert Caster.Mob.kind() == :mob
    assert Caster.Mob.provides() == []
    assert Enum.all?(Caster.Mob.provides(), &Requirement.valid?/1)
    assert Caster.Mob.id(state) == 401
    assert Caster.Mob.unit_type(state) == :mob
    assert Caster.Mob.position(state) == {"prontera", 12, 22}
    assert Caster.Mob.attack_range(state) == 7
    assert Caster.Mob.broadcast_source(state) == {:mob, 401}
  end

  defp player do
    %PlayerState{
      character_id: 101,
      map_name: "prontera",
      x: 10,
      y: 20,
      stats: %PlayerStats{equipment: %Equipment{}}
    }
  end

  defp homunculus do
    %HomunculusState{
      id: 201,
      owner_character_id: 101,
      class_id: 6_001,
      name: "Lif",
      world_gid: 301,
      map_name: "prontera",
      x: 11,
      y: 21,
      attack_range: 3
    }
  end

  defp mob do
    definition = %MobDefinition{
      id: 1_001,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      skill_range: 7,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 400,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 300
    }

    spawn = %MobSpawn{
      mob: 1_001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 12, y: 22}
    }

    MobState.new(401, definition, spawn, "prontera", 12, 22)
  end
end
