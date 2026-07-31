defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdIntoabyss do
  @moduledoc "Into the Abyss (BD_INTOABYSS)."

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
    sp_cost: [70],
    duration: [180_000],
    cast_time: [1_000],
    fixed_cast_time: [500],
    after_cast_delay: [300],
    cooldown: [20_000],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Active
  def cast(caster, _target, level, definition) do
    Perform.perform(caster, definition, level, :sc_intoabyss, fn _ -> [] end, scope: :party)
  end
end
