defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcElementalAttacksTest do
  @moduledoc """
  Definition-table coverage for the flat elemental attack family
  (`NPC_FIREATTACK`, `NPC_WATERATTACK`, `NPC_WINDATTACK`, `NPC_HOLYATTACK`,
  `NPC_UNDEADATTACK`, `NPC_DARKNESSATTACK`) plus `NPC_DARKSTRIKE`: every module
  must resolve through the skill catalog by its `mob_skills.yml` skill id and
  carry the expected element and damage class.

  `NPC_DARKSTRIKE` is `damage_kind: :magic` rather than `:weapon` like its six
  siblings - rAthena's `skill_db` types it `Magic` with a level-scaled hit
  count, unlike the flat single-hit `Weapon` type of the other six.
  """
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcDarknessattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcDarkstrike
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcFireattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcHolyattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcUndeadattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcWaterattack
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcWindattack

  # {module, skill_name, mob_skills.yml skill_id, element, damage_kind}
  @family [
    {NpcFireattack, :npc_fireattack, 186, :fire, :weapon},
    {NpcWaterattack, :npc_waterattack, 184, :water, :weapon},
    {NpcWindattack, :npc_windattack, 187, :wind, :weapon},
    {NpcHolyattack, :npc_holyattack, 189, :holy, :weapon},
    {NpcUndeadattack, :npc_undeadattack, 347, :undead, :weapon},
    {NpcDarknessattack, :npc_darknessattack, 190, :shadow, :weapon},
    {NpcDarkstrike, :npc_darkstrike, 340, :shadow, :magic}
  ]

  test "every module resolves by its mob_skills.yml id with the expected element and damage class" do
    for {module, name, id, element, damage_kind} <- @family do
      assert {:ok, definition} = Catalog.by_id(id),
             "#{inspect(module)}: no definition registered for skill id #{id}"

      assert definition.name == name,
             "#{inspect(module)}: expected name #{inspect(name)}, got #{inspect(definition.name)}"

      assert definition.element == element,
             "#{inspect(module)}: expected element #{inspect(element)}, got #{inspect(definition.element)}"

      assert definition.damage_kind == damage_kind,
             "#{inspect(module)}: expected damage_kind #{inspect(damage_kind)}, got #{inspect(definition.damage_kind)}"

      assert {:ok, ^module} = Catalog.active_module_for(name),
             "#{inspect(module)}: Catalog.active_module_for/1 did not resolve back to this module"
    end
  end
end
