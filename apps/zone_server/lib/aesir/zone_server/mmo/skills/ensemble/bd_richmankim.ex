defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRichmankim do
  @moduledoc """
  Mental Sensing (BD_RICHMANKIM). An ensemble raising experience gained by the party.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  as a party buff within its area. Pre-renewal: an instant cast with no cooldown
  for the classic SP and a 1-minute performance; the classic ground-unit model
  (a field affecting whoever stands in it while both performers keep playing) is
  deferred to a skill-unit performance subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 307,
    name: :bd_richmankim,
    display_name: "Mental Sensing",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    hit_count: 1,
    splash_radius: 15,
    sp_cost: [renewal: [62, 68, 74, 80, 86], pre_renewal: List.duplicate(20, 5)],
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
    Perform.perform(caster, definition, level, :sc_richmankim, fn lv -> [val1: lv] end,
      scope: :party
    )
  end
end
