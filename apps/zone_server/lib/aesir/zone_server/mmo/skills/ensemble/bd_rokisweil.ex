defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRokisweil do
  @moduledoc "Roki's Weil (BD_ROKISWEIL)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 311,
    name: :bd_rokisweil,
    display_name: "Roki's Weil",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :misc,
    splash_radius: 4,
    sp_cost: [180],
    duration: [30_000],
    cast_time: [3_000],
    fixed_cast_time: [1_000],
    after_cast_delay: [300],
    cooldown: [180_000],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform

  @impl Skill.Active
  def cast(caster, _target, level, definition) do
    Perform.perform(caster, definition, level, :sc_rokisweil, fn _level -> [] end, scope: :enemy)
  end
end
