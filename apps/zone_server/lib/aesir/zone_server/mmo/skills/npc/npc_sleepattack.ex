defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSleepattack do
  @moduledoc """
  Sleep Attack (NPC_SLEEPATTACK). Mob-only weapon strike that can sleep.

  100% weapon damage, neutral element, no crit, cast at the mob's configured
  skill range. On a connecting hit it applies `sc_sleep` with no explicit
  duration, falling back to the status definition's own duration.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 182,
    name: :npc_sleepattack,
    display_name: "Sleep Attack",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :neutral

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Npc.StatusStrike

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition),
    do: StatusStrike.cast(caster, target_id, level, definition, :sc_sleep)
end
