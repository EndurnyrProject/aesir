defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcWindattack do
  @moduledoc """
  Wind Attack (NPC_WINDATTACK). Monster-only single-target wind weapon hit at
  `100 * level` percent ATK with a 20% hit-rate bonus (`AttributeStrike`).
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 187,
    name: :npc_windattack,
    requires: [],
    display_name: "Wind Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :wind,
    range: 7

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: AttributeStrike.cast(caster, target_id, level, definition)
end
