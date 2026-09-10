defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaWhistle do
  @moduledoc """
  Whistle (BA_WHISTLE). A song raising FLEE and perfect dodge for the caster's
  party in range, needing an instrument or whip.

  Renewal: FLEE 18 plus 2 per level and perfect dodge (level plus 1)/2, a 1 s
  cast plus 0.3 s fixed, a 0.3 s delay, a 20 s cooldown, and a 3-minute party buff
  within 15 cells. Pre-renewal: FLEE level plus AGI/10 plus Musical Lesson/2 and
  perfect dodge (level plus 1)/2 plus LUK/30 plus Musical Lesson/5, read from the
  performer at cast, an instant cast, no cooldown, and 1 minute; the classic
  ground-song model (a 7x7 field affecting whoever stands in it while the
  performer keeps playing) is deferred to a skill-unit performance subsystem, so
  the party-buff model runs in both modes.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 319,
    name: :ba_whistle,
    display_name: "Whistle",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: [renewal: Enum.to_list(22..40//2), pre_renewal: Enum.to_list(24..60//4)],
    duration: [renewal: List.duplicate(180_000, 10), pre_renewal: List.duplicate(60_000, 10)],
    cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(20_000, 10), pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  @lesson_id 315

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot

  @impl Active
  def cast(caster, :self, level, definition) do
    Snapshot.snapshot(caster, definition, level, :sc_whistle, params(caster, level), [])
  end

  defp params(caster, level) do
    case GameMode.mode() do
      :renewal ->
        [val2: 18 + 2 * level, val3: div(level + 1, 2)]

      :pre_renewal ->
        lesson = Caster.lesson_level(caster, @lesson_id)

        [
          val2: level + div(Caster.stat(caster, :agi), 10) + div(lesson, 2),
          val3: div(level + 1, 2) + div(Caster.stat(caster, :luk), 30) + div(lesson, 5)
        ]
    end
  end
end
