defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcChargearrow do
  @moduledoc """
  Charge Arrow / Arrow Repel (AC_CHARGEARROW). Archer quest skill: a single bow
  hit at 150% ATK that knocks the target back 6 cells.

  rAthena (`db/re/skill_db.yml` id 148): Weapon, single hit, Knockback 6,
  400ms variable / 800ms fixed cast, SP 15, 1 arrow, MaxLevel 1. The ratio is
  `base_skillratio += 50` in `skills/archer/chargearrow.cpp`. Range -9 with
  `AlterRangeVulture`; like the other bow skills we use `range: -1` (the
  weapon's own range) so the Vulture's Eye bonus applies. The bow-equipped
  weapon requirement is not enforced (no weapon-state gate in the interpreter
  yet, matching AC_DOUBLE/AC_SHOWER). Knockback direction is away from the
  caster, mob targets only (PvE simplification shared with Arrow Shower). The
  knockback only fires when the strike actually connects; a dodged or missed
  hit leaves the target in place.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 148,
    name: :ac_chargearrow,
    display_name: "Charge Arrow",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    knockback: 6,
    requires_ammo: true,
    cast_time: [400],
    fixed_cast_time: [800],
    sp_cost: [15],
    quest_skill: true,
    quest_owner_job: :archer

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 150,
      hit_count: 1,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      {:ok, %{hit?: true}} ->
        Combat.knockback(:mob, target_id, caster.x, caster.y, definition.knockback)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end
end
