defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcServiceForYou do
  @moduledoc """
  Gypsy's Kiss (DC_SERVICEFORYOU). A dance raising max SP and cutting SP costs
  for the caster's party in range, needing an instrument or whip.

  Renewal: max SP 9 plus level percent (20 at level 10) and SP costs 5 plus level
  percent lower, a 1 s cast plus 0.3 s fixed, a 0.3 s delay, a 20 s cooldown, and
  3 minutes within 15 cells. Pre-renewal: max SP 15 plus level plus INT/10 plus
  Dancing Lesson/2 percent and SP costs 20 plus 3 per level plus INT/10 plus
  Dancing Lesson/2 percent lower, read from the performer at cast, an instant
  cast, no cooldown, and 3 minutes; the classic ground-dance model is deferred to
  a skill-unit performance subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 330,
    name: :dc_serviceforyou,
    display_name: "Gypsy's Kiss",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: [renewal: Enum.to_list(60..87//3), pre_renewal: Enum.to_list(40..85//5)],
    duration: [renewal: List.duplicate(180_000, 10), pre_renewal: List.duplicate(180_000, 10)],
    cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(20_000, 10), pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  @lesson_id 323

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot

  @impl Active
  def cast(caster, :self, level, definition) do
    Snapshot.snapshot(caster, definition, level, :sc_serviceforyou, params(caster, level), [])
  end

  defp params(caster, level) do
    case GameMode.mode() do
      :renewal ->
        [val1: level]

      :pre_renewal ->
        int_term = div(Caster.stat(caster, :int), 10)
        lesson = div(Caster.lesson_level(caster, @lesson_id), 2)

        [
          val1: level,
          val2: 15 + level + int_term + lesson,
          val3: 20 + 3 * level + int_term + lesson
        ]
    end
  end
end
