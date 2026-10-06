defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcWaterattack do
  @moduledoc """
  Water Attack (NPC_WATERATTACK). Monster-only single-target water weapon hit at
  `100 * level` percent ATK with a 20% hit-rate bonus (`AttributeStrike`).
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 184,
    name: :npc_waterattack,
    requires: [],
    display_name: "Water Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :water,
    range: 7,
    is_npc: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: AttributeStrike.cast(caster, target_id, level, definition)
end
