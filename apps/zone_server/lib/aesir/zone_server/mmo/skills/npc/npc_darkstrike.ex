defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcDarkstrike do
  @moduledoc """
  Dark Strike (NPC_DARKSTRIKE). Monster-only single-target shadow magic that
  deals a level-scaled number of hits at 100% MATK each.

  rAthena renewal: dark element (this project's `:shadow`), hits
  `[1,1,2,2,3,3,4,4,5,5]` (one extra hit every two levels), range 9. Unlike its
  six `NPC_*ATTACK` siblings, DARKSTRIKE is a Magic-type skill in rAthena's
  skill_db, not a flat weapon hit, so it runs through the magic pipeline
  instead of the weapon one.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 340,
    name: :npc_darkstrike,
    display_name: "Dark Strike",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :shadow,
    range: 9

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      hit_count: div(level + 1, 2),
      element: definition.element,
      skip_range: true
    ]

    case Combat.execute_magic_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
