defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcChargearrow do
  @moduledoc """
  Charge Arrow / Arrow Repel (AC_CHARGEARROW). An Archer quest skill: one
  charged bow shot at 150 percent of the attack that hurls the target six cells
  straight away from the archer. It is a single level, fired from nine cells
  away (widened by the caster's Vulture's Eye level), spends one arrow, and
  cannot crit. The knockback only fires when the shot connects; a dodged or
  missed shot leaves the target standing.

  Renewal: the shot is charged in two parts, a 0.4 second wind-up that DEX and
  cast reductions can shorten plus a 0.8 second fixed part that nothing
  shortens, for 1.2 seconds at no DEX.

  Pre-renewal: there is no fixed part, so the whole 1.5 second charge is
  shortened by DEX; a high-DEX archer fires it noticeably faster than a renewal
  one, and a low-DEX archer noticeably slower.

  Knockback is applied to mob targets only, the same player-versus-environment
  simplification Arrow Shower uses.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 148,
    name: :ac_chargearrow,
    requires: [],
    display_name: "Charge Arrow",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 9,
    vulture_range: true,
    knockback: 6,
    requires_ammo: true,
    require_weapon: [:bow],
    cast_time: [renewal: [400], pre_renewal: [1_500]],
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
      skip_range: true,
      base_distance: definition.knockback,
      origin: {caster.x, caster.y},
      native_target_types: [:mob]
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
