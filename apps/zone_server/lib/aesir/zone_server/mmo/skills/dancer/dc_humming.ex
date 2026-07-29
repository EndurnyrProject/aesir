defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcHumming do
  @moduledoc "Focus Ballet (DC_HUMMING)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 327,
    name: :dc_humming,
    display_name: "Focus Ballet",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: Enum.to_list(33..60//3),
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
    Snapshot.snapshot(caster, definition, level, :sc_humming, [val1: level], [])
  end
end
