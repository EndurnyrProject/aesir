defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdLullaby do
  @moduledoc """
  Lullaby (BD_LULLABY). An ensemble putting enemies within 4 cells to sleep.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  to enemies within its area. Pre-renewal: an adjacent partner maintains a
  stationary 9x9 field for one minute, with 1 SP upkeep every 4 seconds each.
  Every 6 seconds it attempts a 30-second sleep on enemies, using both
  performers' INT. Inflicted sleep survives the performance ending.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 306,
    name: :bd_lullaby,
    display_name: "Lullaby",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 4,
    sp_cost: [renewal: [40], pre_renewal: [20]],
    duration: [60_000],
    cast_time: [renewal: [1_000], pre_renewal: []],
    fixed_cast_time: [renewal: [500], pre_renewal: []],
    after_cast_delay: [renewal: [300], pre_renewal: []],
    cooldown: [renewal: [20_000], pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Active
  def cast(caster, :self, level, definition) do
    Perform.perform(caster, definition, level, :sc_sleep, fn _ -> [success_rate: 100] end,
      scope: :enemy
    )
  end
end
