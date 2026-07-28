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

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Song

  @behaviour Active

  @impl Active
  def dynamic_cost(caster, _target, level, definition),
    do: Cost.resolve(caster, definition, level)

  @impl Active
  def cast(caster, :self, level, _definition) do
    Song.snapshot(caster, 322, level, :sc_appleidun, val2: min(9 + level, 20))
  end
end
