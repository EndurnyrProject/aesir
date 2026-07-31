defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdSiegfried do
  @moduledoc "Acoustic Rhythm (BD_SIEGFRIED)."

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
    sp_cost: [40, 44, 48, 52, 56],
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
