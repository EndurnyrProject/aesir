defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcHolyattack do
  @moduledoc """
  Holy Attack (NPC_HOLYATTACK). Monster-only single-target holy weapon hit at
  `100 * level` percent ATK with a 20% hit-rate bonus (`AttributeStrike`).
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 189,
    name: :npc_holyattack,
    requires: [],
    display_name: "Holy Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :holy,
    range: 7

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: AttributeStrike.cast(caster, target_id, level, definition)
end
