defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcFortunekiss do
  @moduledoc """
  Lady Luck (DC_FORTUNEKISS). A dance raising critical for the caster's party in
  range, needing an instrument or whip.

  Renewal: critical 1 per level and critical damage 2 per level percent (read by
  the physical damage pipeline as a critical damage rate), a 1 s
  cast plus 0.3 s fixed, a 0.3 s delay, a 20 s cooldown, and 3 minutes within 15
  cells. Pre-renewal: critical 10 plus level plus LUK/10 plus Dancing Lesson/2
  read from the performer at cast with no critical damage bonus, an instant cast,
  no cooldown, and 2 minutes; the classic ground-dance model is deferred to a
  skill-unit performance subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 329,
    name: :dc_fortunekiss,
    display_name: "Lady Luck",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: [renewal: Enum.to_list(40..85//5), pre_renewal: Enum.to_list(43..70//3)],
    duration: [renewal: List.duplicate(180_000, 10), pre_renewal: List.duplicate(120_000, 10)],
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
      :sc_fortunekiss,
      params(caster, level),
      []
    )
  end

  defp params(caster, level) do
    case GameMode.mode() do
      :renewal ->
        [val1: level]

      :pre_renewal ->
        critical =
          10 + level + div(Caster.stat(caster, :luk), 10) +
            div(Caster.lesson_level(caster, @lesson_id), 2)

        [val1: level, val2: critical]
    end
  end
end
