defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcHumming do
  @moduledoc """
  Focus Ballet (DC_HUMMING). A dance raising HIT for the caster's party in range,
  needing an instrument or whip.

  Renewal: HIT 4 per level, a 1 s cast plus 0.3 s fixed, a 0.3 s delay, a 20 s
  cooldown, and 3 minutes within 15 cells. Pre-renewal: HIT 1 plus 2 per level plus
  DEX/10 plus Dancing Lesson read from the performer at cast, an instant cast, no
  cooldown, and 1 minute; the classic ground-dance model (a 7x7 field affecting
  whoever stands in it while the performer keeps dancing) is deferred to a
  skill-unit performance subsystem, so the party-buff model runs in both modes.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 327,
    name: :dc_humming,
    display_name: "Focus Ballet",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: [renewal: Enum.to_list(33..60//3), pre_renewal: Enum.to_list(22..40//2)],
    duration: [renewal: List.duplicate(180_000, 10), pre_renewal: List.duplicate(60_000, 10)],
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
    Snapshot.snapshot(caster, definition, level, :sc_humming, params(caster, level), [])
  end

  defp params(caster, level) do
    case GameMode.mode() do
      :renewal ->
        [val1: level]

      :pre_renewal ->
        hit =
          1 + 2 * level + div(Caster.stat(caster, :dex), 10) +
            Caster.lesson_level(caster, @lesson_id)

        [val1: level, val2: hit]
    end
  end
end
