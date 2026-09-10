defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdIntoabyss do
  @moduledoc """
  Power Chord (BD_INTOABYSS). An ensemble freeing the party from gemstone costs.

  Renewal: cast, fixed cast, delay, cooldown, SP, and duration as declared, applied
  as a party buff within its area. Pre-renewal: an instant cast with no cooldown
  for the classic SP and a 1-minute performance; the classic ground-unit model
  (a field affecting whoever stands in it while both performers keep playing) is
  deferred to a skill-unit performance subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 312,
    name: :bd_intoabyss,
    display_name: "Into the Abyss",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    hit_count: 1,
    splash_radius: 15,
    sp_cost: [renewal: [70], pre_renewal: [10]],
    duration: [renewal: [180_000], pre_renewal: [60_000]],
    cast_time: [renewal: [1_000], pre_renewal: []],
    fixed_cast_time: [renewal: [500], pre_renewal: []],
    after_cast_delay: [renewal: [300], pre_renewal: []],
    cooldown: [renewal: [20_000], pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Active
  def cast(caster, _target, level, definition) do
    Perform.perform(caster, definition, level, :sc_intoabyss, fn _ -> [] end, scope: :party)
  end
end
