defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdLullaby do
  @moduledoc """
  Lullaby (BD_LULLABY). An ensemble putting enemies within 4 cells to sleep.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  as a party buff within its area. Pre-renewal: an instant cast with no cooldown
  for the classic SP and a 1-minute performance; the classic ground-unit model
  (a field affecting whoever stands in it while both performers keep playing) is
  deferred to a skill-unit performance subsystem.
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
