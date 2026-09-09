defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolylight do
  @moduledoc """
  Holy Light (AL_HOLYLIGHT). Acolyte quest skill: a single-target holy magic
  attack at 125 percent MATK that also strips the target's Kyrie Eleison barrier
  and its Praefatio-style variant.

  The 125 percent ratio carries no base-level scaling term in either mode: Holy
  Light is one of the damaging skills whose renewal ratio is flat.

  Renewal: single level, fifteen SP, range nine, an 800ms variable cast plus a
  fixed 200ms, no after-cast delay.

  Pre-renewal: a flat two-second cast with no fixed component. Element, ratio,
  range, cost and the barrier strip are identical in both modes.
  """
  # NOTE: Aesir has no SC_SPIRIT/SL_PRIEST. When it exists, make the linked-caster
  # Holy Light SP cost five times normal and remove this note.
  use Aesir.ZoneServer.Mmo.Skill,
    id: 156,
    name: :al_holylight,
    requires: [],
    display_name: "Holy Light",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :holy,
    range: 9,
    cast_time: [renewal: [800], pre_renewal: [2_000]],
    fixed_cast_time: [renewal: [200], pre_renewal: []],
    sp_cost: [15],
    quest_skill: true,
    quest_owner_job: :acolyte

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
      {:ok, _ref} ->
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
