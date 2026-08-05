defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcCurseattack do
  @moduledoc """
  Curse Attack (NPC_CURSEATTACK). Mob-only weapon strike that can curse.

  100% weapon damage, shadow element, no crit, cast at the mob's configured
  skill range. On a connecting hit it applies `sc_curse` with no explicit
  duration, falling back to the status definition's own duration.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 181,
    name: :npc_curseattack,
    requires: [],
    display_name: "Curse Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :shadow

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.StatusStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: StatusStrike.cast(caster, target_id, level, definition, :sc_curse)
end
