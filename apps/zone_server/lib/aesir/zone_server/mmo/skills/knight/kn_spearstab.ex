defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearstab do
  @moduledoc """
  Spear Stab (KN_SPEARSTAB). A spear thrust that pierces the straight line
  between the Knight and the target.

  Every living enemy standing on the line of cells from the caster to the
  target's cell (inclusive of the target's own cell) takes a single hit for
  `(100 + 20 * level)%` of the caster's weapon attack; an enemy standing off
  that line, even one closer to the caster, is untouched, and every struck
  target is pushed six cells away from the caster in both modes.

  Only usable with a spear equipped. Mobs bypass the weapon gate since they
  cast this skill through their mob-skill rows rather than an equipped item.

  Renewal and pre-renewal agree: 100% plus 20% per level weapon damage along a 4-cell line with a spear, pushing every target hit 6 cells.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 58,
    name: :kn_spearstab,
    requires: [],
    display_name: "Spear Stab",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 4,
    knockback: 6,
    require_weapon: [:one_handed_spear, :two_handed_spear],
    sp_cost: List.duplicate(9, 10),
    damage_splash: true

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 20 * level,
      skip_crit: true,
      base_distance: definition.knockback,
      delivery: :splash
    ]

    Combat.execute_line_attack(caster, target_id, opts)

    {:ok, caster}
  end
end
