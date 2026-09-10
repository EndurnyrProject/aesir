defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaPoembragi do
  @moduledoc """
  A Poem of Bragi (BA_POEMBRAGI). A song cutting variable cast and after-cast
  delay for the caster's party in range, needing an instrument or whip.

  Renewal: 2% cast and 3% delay per level, a 1 s cast plus 0.3 s fixed, a 0.3 s
  delay, a 20 s cooldown, and 3 minutes within 15 cells. Pre-renewal: cast
  3 per level plus DEX/10 plus Musical Lesson percent and delay 3 per level (50 at
  level 10) plus INT/5 plus twice Musical Lesson percent, read from the performer
  at cast, an instant cast, no cooldown, and 3 minutes; the classic ground-song
  model is deferred to a skill-unit performance subsystem, so the party-buff model
  runs in both modes.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 321,
    name: :ba_poembragi,
    display_name: "A Poem of Bragi",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: [renewal: Enum.to_list(65..110//5), pre_renewal: Enum.to_list(40..85//5)],
    duration: List.duplicate(180_000, 10),
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
    Snapshot.snapshot(caster, definition, level, :sc_poembragi, params(caster, level), [])
  end

  defp params(caster, level) do
    case GameMode.mode() do
      :renewal ->
        [val2: 2 * level, val3: 3 * level]

      :pre_renewal ->
        lesson = Caster.lesson_level(caster, @lesson_id)
        delay = if level < 10, do: 3 * level, else: 50

        [
          val2: 3 * level + div(Caster.stat(caster, :dex), 10) + lesson,
          val3: delay + div(Caster.stat(caster, :int), 5) + 2 * lesson
        ]
    end
  end
end
