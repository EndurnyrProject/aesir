defmodule Aesir.ZoneServer.Npc.SkillCasterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Npc.SkillCaster

  test "builds a complete combatant with deterministic magic attack" do
    combatant =
      SkillCaster.new(1_001, 99, 60, {150, 150}, "prontera") |> SkillCaster.to_combatant()

    assert %Combatant{} = combatant
    assert combatant.base_stats == %{str: 99, agi: 99, vit: 99, int: 99, dex: 99, luk: 99}
    assert combatant.progression.base_level == 60

    assert %{matk: 215, matk_min: 215, matk_max: 215, heal_matk_min: 215, heal_matk_max: 215} =
             combatant.combat_stats

    assert %{atk: 0, def: 0, flee: 0, hit: 0, mdef: 0, perfect_dodge: 0, soft_mdef: 0} =
             combatant.combat_stats
  end

  test "resolves as an NPC caster with no facilities" do
    caster = SkillCaster.new(1_001, 99, 60, {150, 150}, "prontera")

    assert Caster.for(caster) == SkillCaster
    assert Caster.for_kind(:npc) == SkillCaster
    assert SkillCaster.kind() == :npc
    assert SkillCaster.provides() == []
    assert SkillCaster.id(caster) == 1_001
    assert SkillCaster.unit_type(caster) == :npc
    assert SkillCaster.position(caster) == {"prontera", 150, 150}
    assert SkillCaster.attack_range(caster) == 1
    assert SkillCaster.broadcast_source(caster) == {:npc, 1_001}
    assert SkillCaster.sp(caster) == 0
    assert SkillCaster.deduct_sp(caster, 10) == caster

    assert {:ok, definition} = Catalog.by_name(:al_heal)
    assert Castability.check(definition, :npc) == :ok
  end
end
