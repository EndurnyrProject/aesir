defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdSiegfried do
  @moduledoc """
  Acoustic Rhythm (BD_SIEGFRIED). An ensemble raising the party's elemental resistances.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  as a party buff within its area. Pre-renewal: an instant cast with no cooldown
  for the classic SP and a 1-minute performance; the classic ground-unit model
  (a field affecting whoever stands in it while both performers keep playing) is
  deferred to a skill-unit performance subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 313,
    name: :bd_siegfried,
    display_name: "Acoustic Rhythm",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    splash_radius: 15,
    hit_count: 1,
    sp_cost: [renewal: [40, 44, 48, 52, 56], pre_renewal: List.duplicate(20, 5)],
    duration: [renewal: List.duplicate(180_000, 5), pre_renewal: List.duplicate(60_000, 5)],
    cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 5), pre_renewal: []],
    cooldown: [renewal: List.duplicate(20_000, 5), pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Active
  def cast(caster, _target, level, definition) do
    Perform.perform(
      caster,
      definition,
      level,
      :sc_siegfried,
      fn effective_level -> [val1: 3 * effective_level, val2: 5 * effective_level] end,
      scope: :party
    )
  end
end
