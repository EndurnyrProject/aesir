defmodule Aesir.ZoneServer.Mmo.Skills.AlHolylight do
  @moduledoc """
  Holy Light (AL_HOLYLIGHT). Acolyte quest skill: single-target holy magic
  attack at 125% MATK.

  rAthena (`db/re/skill_db.yml` id 156): Magic, Holy element, single hit,
  range 9, 800ms variable / 200ms fixed cast, SP 15, MaxLevel 1. The ratio is
  `base_skillratio += 25` in `skills/acolyte/holylight.cpp`
  (`calculateSkillRatio`), i.e. 125% MATK.

  TODO: Not mirrored (out of scope until their systems exist): ending `SC_P_ALTER`
  on the target, breaking Kyrie Eleison (SC_KYRIE check), and the
  Soul Linker `SL_PRIEST` 5x multiplier.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 156,
    name: :al_holylight,
    display_name: "Holy Light",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :holy,
    range: 9,
    cast_time: [800],
    fixed_cast_time: [200],
    sp_cost: [15]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 125,
      hit_count: 1,
      element: definition.element
    ]

    case Combat.execute_magic_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
