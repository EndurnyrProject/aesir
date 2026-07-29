defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcDontforgetme do
  @moduledoc "Slow Grace (DC_DONTFORGETME)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 328,
    name: :dc_dontforgetme,
    display_name: "Slow Grace",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 4,
    sp_cost: Enum.to_list(38..65//3),
    duration: List.duplicate(60_000, 10),
    cast_time: List.duplicate(1_000, 10),
    fixed_cast_time: List.duplicate(300, 10),
    after_cast_delay: List.duplicate(300, 10),
    cooldown: List.duplicate(20_000, 10),
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot

  @impl Skill.Active
  def cast(caster, :self, level, definition) do
    Snapshot.snapshot(
      caster,
      definition,
      level,
      :sc_dontforgetme,
      [val1: level, val2: 1 + 30 * level, val3: 5 + 2 * level],
      scope: :enemy
    )
  end
end
