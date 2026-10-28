defmodule Aesir.ZoneServer.Mmo.Skills.Stalker.StRejectsword do
  @moduledoc """
  Counter Instinct (ST_REJECTSWORD). In renewal and pre-renewal, starts Counter
  Instinct (`sc_rejectsword`) on the caster at the cast level for 10 to 30 SP:
  a 15 percent per level chance to halve a weapon hit and return the halved
  amount, three times. Monsters cast it on themselves the same way.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 390,
    name: :st_rejectsword,
    requires: [],
    status: :sc_rejectsword,
    display_name: "Counter Instinct",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [10, 15, 20, 25, 30]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
  def cast(caster, _target, level, _definition) do
    unit_type = caster.__struct__.get_unit_type(caster)
    unit_id = caster.__struct__.get_unit_id(caster)

    StatusInterpreter.apply_status(unit_type, unit_id, :sc_rejectsword,
      val1: level,
      caster_id: unit_id,
      source_type: unit_type
    )

    {:ok, caster}
  end
end
