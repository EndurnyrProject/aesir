defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcPoisonattack do
  @moduledoc """
  Poison Attack (NPC_POISONATTACK). Monster-only single-target poison weapon hit at
  `100 * level` percent ATK with a 20% hit-rate bonus (`AttributeStrike`).
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 188,
    name: :npc_poisonattack,
    requires: [],
    display_name: "Poison Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :poison,
    range: 7,
    is_npc: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: AttributeStrike.cast(caster, target_id, level, definition)
end
