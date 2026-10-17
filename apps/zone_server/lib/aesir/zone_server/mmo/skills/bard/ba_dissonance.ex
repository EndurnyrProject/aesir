defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaDissonance do
  @moduledoc """
  Dissonance (BA_DISSONANCE). A song needing an instrument.

  A no-damage cast in both modes: the cast itself never counts as a damaging
  skill (no Mystical Amplification use, no when-hit procs on the targets).

  Renewal: a magic skill. A player's cast immediately splashes neutral magic
  damage within 4 cells, with a 1 s cast plus 0.3 s fixed, a 0.3 s delay, a 5 s
  cooldown and 35 to 47 SP. A monster's cast does nothing.

  Pre-renewal: a misc skill. The cast places a 30-second 7x7 enemy field on the
  performer, dealing neutral misc damage every 3 seconds and costing a player
  1 SP every 3 seconds. A monster performs it the same way, with no lesson
  bonus and no SP paid.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 317,
    name: :ba_dissonance,
    cast_cancel: [renewal: false, pre_renewal: true],
    display_name: "Dissonance",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    ignore_flee: true,
    damage_kind: [renewal: :magic, pre_renewal: :misc],
    element: :neutral,
    range: 0,
    hit_count: 1,
    splash_radius: 4,
    duration: [renewal: [], pre_renewal: List.duplicate(30_000, 5)],
    sp_cost: [renewal: [35, 38, 41, 44, 47], pre_renewal: [18, 21, 24, 27, 30]],
    cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 5), pre_renewal: []],
    cooldown: [renewal: List.duplicate(5_000, 5), pre_renewal: []],
    require_weapon: [:musical]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @impl Active
  def cast(%PlayerState{} = caster, :self, level, definition) do
    case GameMode.mode() do
      :renewal -> cast_self(caster, level, definition)
      :pre_renewal -> perform(caster, level, definition)
    end
  end

  def cast(%MobState{instance_id: id} = caster, {:unit, id}, level, definition) do
    case GameMode.mode() do
      :renewal -> {:ok, caster}
      :pre_renewal -> perform(caster, level, definition)
    end
  end

  defp perform(caster, level, definition) do
    Performance.perform(caster, definition, level, nil, [],
      kind: :song,
      reach: :enemy,
      linger_ms: 0,
      upkeep: 3,
      tick: :dissonance,
      tick_interval: 3_000,
      no_overlap: true,
      lesson_level: Caster.lesson_level(caster, 315)
    )
  end

  defp cast_self(%{x: x, y: y} = caster, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(caster, level),
      element: definition.element,
      split: false
    ]

    Combat.execute_magic_splash(caster, {x, y}, definition.splash_radius, opts)
    {:ok, remember(caster, level)}
  end

  defp skill_ratio(%PlayerState{stats: %{progression: %{job_level: job_level}}}, level),
    do: div((110 + 50 * level) * job_level, 10)

  defp remember(caster, level), do: Snapshot.remember(caster, 317, level)
end
