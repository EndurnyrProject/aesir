defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcPoisonattack do
  @moduledoc """
  Poison Attack (NPC_POISONATTACK). Mob-only weapon strike that can poison.

  100% weapon damage, poison element, no crit, cast at the mob's configured
  skill range. On a connecting hit it applies `sc_poison` with no explicit
  duration, falling back to the status definition's own duration.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 188,
    name: :npc_poisonattack,
    display_name: "Poison Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :poison

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.StatusStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: StatusStrike.cast(caster, target_id, level, definition, :sc_poison)
end
