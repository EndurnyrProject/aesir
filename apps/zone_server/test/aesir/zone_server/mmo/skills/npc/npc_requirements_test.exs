defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcRequirementsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Castability

  @modules [
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcAgiup,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcAllheal,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcBleeding,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcBlindattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcCallslave,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcCurseattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcDarknessattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcDarkstrike,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcEarthquake,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcFireattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcGroundattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcHolyattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcPoison,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcPoisonattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcRandommove,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcSilenceattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcSleepattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcStunattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcSummonslave,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcUndeadattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcWaterattack,
    Aesir.ZoneServer.Mmo.Skills.Npc.NpcWindattack
  ]

  test "npc skills require no player-only facilities and are mob-castable" do
    for module <- @modules do
      definition = module.definition()

      assert definition.requires == []
      assert Castability.check(definition, :mob) == :ok
    end
  end
end
