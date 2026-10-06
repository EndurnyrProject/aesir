defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcDarknessattack do
  @moduledoc """
  Darkness Attack (NPC_DARKNESSATTACK). Monster-only single-target shadow weapon hit at
  `100 * level` percent ATK with a 20% hit-rate bonus (`AttributeStrike`).
  Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 190,
    name: :npc_darknessattack,
    requires: [],
    display_name: "Darkness Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :shadow,
    range: 7,
    is_npc: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.AttributeStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: AttributeStrike.cast(caster, target_id, level, definition)
end
