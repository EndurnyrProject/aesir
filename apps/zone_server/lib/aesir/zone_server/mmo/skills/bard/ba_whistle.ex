defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaWhistle do
  @moduledoc "Whistle (BA_WHISTLE)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 319,
    name: :ba_whistle,
    display_name: "Whistle",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: Enum.to_list(22..40//2),
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
    Song.snapshot(caster, 319, level, :sc_whistle,
      val2: 18 + 2 * level,
      val3: div(level + 1, 2)
    )
  end
end
