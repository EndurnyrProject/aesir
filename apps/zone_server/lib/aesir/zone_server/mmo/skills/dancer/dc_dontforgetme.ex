defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcDontforgetme do
  @moduledoc """
  Slow Grace (DC_DONTFORGETME). A dance slowing the attack and movement speed of
  enemies within 4 cells, needing an instrument or whip.

  Renewal: attack speed minus 3 per level percent and movement 5 plus 2 per level
  percent slower, a 1 s cast plus 0.3 s fixed, a 0.3 s delay, a 20 s cooldown,
  and 1 minute. Pre-renewal: attack speed minus 5 plus 3 per level plus DEX/10
  plus Dancing Lesson percent and movement 5 plus 3 per level plus AGI/10 plus
  Dancing Lesson percent slower, read from the performer at cast, an instant cast,
  no cooldown, and 3 minutes; the classic ground-dance model is deferred to a
  skill-unit performance subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 328,
    name: :dc_dontforgetme,
    display_name: "Slow Grace",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 4,
    sp_cost: [renewal: Enum.to_list(38..65//3), pre_renewal: Enum.to_list(28..55//3)],
    duration: [renewal: List.duplicate(60_000, 10), pre_renewal: List.duplicate(180_000, 10)],
    cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(20_000, 10), pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  @lesson_id 323

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot

  @impl Skill.Active
  def cast(caster, :self, level, definition) do
    Snapshot.snapshot(
      caster,
      definition,
      level,
      :sc_dontforgetme,
      params(caster, level),
      scope: :enemy
    )
  end

  defp params(caster, level) do
    case GameMode.mode() do
      :renewal ->
        [val1: level, val2: 1 + 30 * level, val3: 5 + 2 * level]

      :pre_renewal ->
        lesson = Caster.lesson_level(caster, @lesson_id)

        [
          val1: level,
          val2: 5 + 3 * level + div(Caster.stat(caster, :dex), 10) + lesson,
          val3: 5 + 3 * level + div(Caster.stat(caster, :agi), 10) + lesson
        ]
    end
  end
end
