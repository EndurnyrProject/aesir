defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdEternalchaos do
  @moduledoc """
  Eternal Chaos (BD_ETERNALCHAOS). An ensemble zeroing the DEF of enemies within 4 cells.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  to enemies within its area. Pre-renewal: an adjacent partner maintains a
  stationary 9x9 field for one minute, with 1 SP upkeep every 4 seconds each.
  Enemy occupants lose the effect immediately when leaving.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 308,
    name: :bd_eternalchaos,
    display_name: "Eternal Chaos",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    hit_count: 1,
    splash_radius: 4,
    sp_cost: [renewal: [120], pre_renewal: [30]],
    duration: [60_000],
    cast_time: [renewal: [1_000], pre_renewal: []],
    fixed_cast_time: [renewal: [500], pre_renewal: []],
    after_cast_delay: [renewal: [300], pre_renewal: []],
    cooldown: [renewal: [60_000], pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Skill.Active
  def cast(caster, _target, level, definition) do
    Perform.perform(caster, definition, level, :sc_eternalchaos, fn _level -> [] end,
      scope: :enemy
    )
  end
end
