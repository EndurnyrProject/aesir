defmodule Aesir.ZoneServer.Mmo.Skills.Stalker.StPreserve do
  @moduledoc """
  Preserve (ST_PRESERVE). In renewal and pre-renewal, starts Preserve
  (`sc_preserve`) on the caster for 10 minutes for 30 SP, keeping the skill
  Plagiarism copied. Renewal: a 1 s fixed cast. Pre-renewal: a 1 s cast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 475,
    name: :st_preserve,
    requires: [],
    status: :sc_preserve,
    display_name: "Preserve",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :none,
    sp_cost: [30],
    cast_time: [renewal: [0], pre_renewal: [1_000]],
    fixed_cast_time: [renewal: [1_000], pre_renewal: []],
    duration: [600_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
  def cast(caster, _target, level, definition) do
    unit_type = caster.__struct__.get_unit_type(caster)
    unit_id = caster.__struct__.get_unit_id(caster)

    StatusInterpreter.apply_status(unit_type, unit_id, :sc_preserve,
      val1: level,
      duration: Enum.at(definition.duration, level - 1),
      caster_id: unit_id,
      source_type: unit_type
    )

    {:ok, caster}
  end
end
