defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaAssassincross do
  @moduledoc """
  Assassin Cross of Sunset (BA_ASSASSINCROSS). A song raising attack speed for
  the caster's party in range, needing an instrument or whip.

  Renewal: a flat attack speed of 2 per level minus 1 (20 at level 10), a 1 s
  cast plus 0.3 s fixed, a 0.3 s delay, a 20 s cooldown, and 3 minutes within 15
  cells. Pre-renewal: an attack speed rate of 5 plus level plus AGI/20 plus
  Musical Lesson/2 percent read from the performer at cast, an instant cast, no
  cooldown, and 2 minutes; the classic ground-song model is deferred to a
  skill-unit performance subsystem, so the party-buff model runs in both modes.
  """

  import Bitwise

  use Aesir.ZoneServer.Mmo.Skill,
    id: 320,
    name: :ba_assassincross,
    display_name: "Assassin Cross of Sunset",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 15,
    sp_cost: [renewal: Enum.to_list(40..85//5), pre_renewal: Enum.to_list(38..65//3)],
    duration: [renewal: List.duplicate(180_000, 10), pre_renewal: List.duplicate(120_000, 10)],
    cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(20_000, 10), pre_renewal: []],
    require_weapon: [:musical, :whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  @lesson_id 315

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @mado_option Option.id(:madogear)

  @impl Active
  def cast(caster, :self, level, definition) do
    Snapshot.snapshot(caster, definition, level, :sc_assncross, [val2: aspd(caster, level)],
      eligible?: &eligible?/1
    )
  end

  defp aspd(caster, level) do
    case GameMode.mode() do
      :renewal ->
        if level == 10, do: 20, else: 2 * level - 1

      :pre_renewal ->
        5 + level + div(Caster.stat(caster, :agi), 20) +
          div(Caster.lesson_level(caster, @lesson_id), 2)
    end
  end

  defp eligible?(recipient) do
    not StatusStorage.has_status?(:player, recipient.character_id, :sc_quagmire) and
      (recipient.option &&& @mado_option) == 0
  end
end
