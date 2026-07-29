defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaAppleidun do
  @moduledoc "The Apple of Idun (BA_APPLEIDUN)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 322,
    name: :ba_appleidun,
    display_name: "The Apple of Idun",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: Enum.to_list(40..85//5),
    duration: List.duplicate(180_000, 10),
    cast_time: List.duplicate(1_000, 10),
    fixed_cast_time: List.duplicate(300, 10),
    after_cast_delay: List.duplicate(300, 10),
    cooldown: List.duplicate(20_000, 10),
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot

  @impl Active
  def cast(caster, :self, level, definition) do
    Snapshot.snapshot(
      caster,
      definition,
      level,
      :sc_appleidun,
      [val2: min(9 + level, 20)],
      []
    )
  end
end
