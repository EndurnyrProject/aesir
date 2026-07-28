defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaDissonance do
  @moduledoc "Dissonance (BA_DISSONANCE)."

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
    sp_cost: [35, 38, 41, 44, 47],
    cast_time: List.duplicate(1_000, 5),
    fixed_cast_time: List.duplicate(300, 5),
    after_cast_delay: List.duplicate(300, 5),
    cooldown: List.duplicate(5_000, 5),
    require_weapon: [:musical]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Bard.Song
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  def dynamic_cost(caster, _target, level, definition),
    do: Cost.resolve(caster, definition, level)

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

  defp remember(%PlayerState{} = caster, level), do: Song.remember(caster, 317, level)
  defp remember(caster, _level), do: caster
end
