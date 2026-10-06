defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcGroundattack do
  @moduledoc """
  Ground Attack (NPC_GROUNDATTACK). Monster-only single-target earth weapon hit at
  `100 * level` percent ATK with a 20% hit-rate bonus (`AttributeStrike`).
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 185,
    name: :npc_groundattack,
    requires: [],
    display_name: "Ground Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :earth,
    range: 7,
    target_hidden: true,
    is_npc: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: AttributeStrike.cast(caster, target_id, level, definition)
end
