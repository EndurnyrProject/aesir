defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcTelekinesisattack do
  @moduledoc """
  Ghost Attribute Attack (NPC_TELEKINESISATTACK). Monster-only single-target ghost weapon
  hit at `100 * level` percent ATK with a 20% hit-rate bonus (`AttributeStrike`).
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 191,
    name: :npc_telekinesisattack,
    requires: [],
    display_name: "Ghost Attribute Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :ghost,
    range: 7

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: AttributeStrike.cast(caster, target_id, level, definition)
end
