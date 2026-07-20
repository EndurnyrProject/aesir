defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolylight do
  @moduledoc """
  Holy Light (AL_HOLYLIGHT). Acolyte quest skill: single-target holy magic
  attack at 125% MATK.

  rAthena (`db/re/skill_db.yml` id 156): Magic, Holy element, single hit,
  range 9, 800ms variable / 200ms fixed cast, SP 15, MaxLevel 1. The ratio is
  `base_skillratio += 25` in `skills/acolyte/holylight.cpp`
  (`calculateSkillRatio`), i.e. 125% MATK.

  A connected hit ends `SC_P_ALTER` and `SC_KYRIE`, matching
  `skills/acolyte/holylight.cpp` and `battle.cpp:1291-1302`.
  """
  # NOTE: Aesir has no SC_SPIRIT/SL_PRIEST. When it exists, make the linked-caster
  # Holy Light SP cost five times normal and remove this note.
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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    # NOTE: Aesir has no SC_SPIRIT/SL_PRIEST. When it exists, apply its fivefold
    # Holy Light damage ratio for linked casters and remove this note.
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 125,
      hit_count: 1,
      element: definition.element,
      skip_range: true
    ]

    case Combat.execute_magic_attack(caster, target_id, opts) do
      :ok ->
        unit_type = target_unit_type(target_id)
        StatusInterpreter.remove_status(unit_type, target_id, :sc_p_alter)
        StatusInterpreter.remove_status(unit_type, target_id, :sc_kyrie)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
