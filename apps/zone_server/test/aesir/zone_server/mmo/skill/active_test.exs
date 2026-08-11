defmodule Aesir.ZoneServer.Mmo.Skill.ActiveTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "returns a player caster's character id" do
    assert Active.caster_unit_id(%PlayerState{character_id: 1_001}) == 1_001
  end

  test "returns a mob caster's instance id" do
    caster = %MobState{
      instance_id: 2_001,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 0,
      y: 0,
      map_name: "prontera",
      hp: 1,
      max_hp: 1,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    assert Active.caster_unit_id(caster) == 2_001
  end

  test "returns an NPC caster's gid" do
    caster = SkillCaster.new(3_001, 99, 60, {150, 150}, "prontera")

    assert Active.caster_unit_id(caster) == 3_001
  end
end
