defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaAppleidun do
  @moduledoc """
  The Apple of Idun (BA_APPLEIDUN). A song raising max HP for the caster's
  party in range, needing an instrument or whip.

  Renewal: max HP 9 plus level percent (20 at level 10) with healing over time,
  a 1 s cast plus 0.3 s fixed, a 0.3 s delay, a 20 s cooldown, and 3 minutes
  within 15 cells. Pre-renewal: max HP 5 plus 2 per level plus VIT/10 plus
  Musical Lesson/2 percent read from the performer at cast, an instant cast, no
  cooldown, and 3 minutes; the classic tick heal (30 plus 5 per level plus VIT/2
  plus 5 per Musical Lesson level every 3 s to whoever stands in the field) belongs
  to the deferred skill-unit performance subsystem.
  """

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
    Snapshot.snapshot(
      caster,
      definition,
      level,
      :sc_appleidun,
      [val2: hp_rate(caster, level)],
      []
    )
  end

  defp hp_rate(caster, level) do
    case GameMode.mode() do
      :renewal ->
        min(9 + level, 20)

      :pre_renewal ->
        5 + 2 * level + div(Caster.stat(caster, :vit), 10) +
          div(Caster.lesson_level(caster, @lesson_id), 2)
    end
  end
end
