defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRichmankim do
  @moduledoc "Mr. Kim a Rich Man (BD_RICHMANKIM)."

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
    sp_cost: [62, 68, 74, 80, 86],
    duration: List.duplicate(180_000, 5),
    cast_time: List.duplicate(1_000, 5),
    fixed_cast_time: List.duplicate(500, 5),
    after_cast_delay: List.duplicate(300, 5),
    cooldown: List.duplicate(20_000, 5),
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
