defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaDissonance do
  @moduledoc """
  Dissonance (BA_DISSONANCE). A song dealing periodic neutral magic damage to
  enemies within 4 cells of the performer, needing an instrument.

  Renewal: a 1 s cast plus 0.3 s fixed, a 0.3 s delay, a 5 s cooldown, and 35 to 47
  SP. Pre-renewal: an instant cast with no cooldown for 18 to 30 SP; the classic
  ground-field model is deferred to a skill-unit performance subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 317,
    name: :ba_dissonance,
    display_name: "Dissonance",
    max_level: 5,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :magic,
    element: :neutral,
    range: 0,
    hit_count: 1,
    splash_radius: 4,
    sp_cost: [renewal: [35, 38, 41, 44, 47], pre_renewal: [18, 21, 24, 27, 30]],
    cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 5), pre_renewal: []],
    cooldown: [renewal: List.duplicate(5_000, 5), pre_renewal: []],
    require_weapon: [:musical]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @impl Active
  def cast(%PlayerState{} = caster, :self, level, definition),
    do: cast_self(caster, level, definition)

  def cast(%MobState{instance_id: id} = caster, {:unit, id}, level, definition),
    do: cast_self(caster, level, definition)

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

  defp skill_ratio(
         %PlayerState{stats: %{progression: %{job_level: job_level}}},
         level
       ) do
    div((110 + 50 * level) * job_level, 10)
  end

  defp skill_ratio(_caster, level), do: 110 + 50 * level

  defp remember(%PlayerState{} = caster, level), do: Snapshot.remember(caster, 317, level)
  defp remember(caster, _level), do: caster
end
