defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRokisweil do
  @moduledoc """
  Classical Pluck (BD_ROKISWEIL). An ensemble that blocks skill use in the area.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  to enemies within its area. Pre-renewal: an adjacent partner maintains a
  stationary 9x9 field for one minute, with 1 SP upkeep every 4 seconds each.
  All player and monster occupants except the performers are skill-blocked
  only while inside, including allies.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 311,
    name: :bd_rokisweil,
    display_name: "Roki's Weil",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    splash_radius: 4,
    sp_cost: [renewal: [180], pre_renewal: [15]],
    duration: [renewal: [30_000], pre_renewal: [60_000]],
    cast_time: [renewal: [3_000], pre_renewal: []],
    fixed_cast_time: [renewal: [1_000], pre_renewal: []],
    after_cast_delay: [renewal: [300], pre_renewal: []],
    cooldown: [renewal: [180_000], pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Skill.Active
  def cast(caster, _target, level, definition) do
    Perform.perform(caster, definition, level, :sc_rokisweil, fn _level -> [] end, scope: :enemy)
  end
end
