defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdEternalchaos do
  @moduledoc "Eternal Chaos (BD_ETERNALCHAOS)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 308,
    name: :bd_eternalchaos,
    display_name: "Eternal Chaos",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    hit_count: 1,
    splash_radius: 4,
    sp_cost: [120],
    duration: [60_000],
    cast_time: [1_000],
    fixed_cast_time: [500],
    after_cast_delay: [300],
    cooldown: [60_000],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Skill.Active
  def cast(caster, _target, level, definition) do
    Perform.perform(caster, definition, level, :sc_eternalchaos, fn _level -> [] end,
      scope: :enemy
    )
  end
end
