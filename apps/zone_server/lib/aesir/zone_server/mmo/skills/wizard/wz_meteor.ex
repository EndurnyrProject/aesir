defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteor do
  @moduledoc """
  Meteor Storm (WZ_METEOR), a scheduled Fire ground attack.

  rAthena `skills/mage/meteorstorm.cpp:13-22` schedules one random impact per
  second within the 7x7 target area. `skill.cpp:12437-12439` lands each impact
  700 ms after its visual effect begins. The skill-unit manager owns that
  schedule, so casts never create a process per meteor. Renewal damage is base
  MATK plus 25 (`meteorstorm.cpp:25-29`), and each successful impact attempts
  Stun at `3 * skill_lv` percent for `Duration2` (`meteorstorm.cpp:31-33`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 83,
    name: :wz_meteor,
    display_name: "Meteor Storm",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :fire,
    splash_radius: 3,
    hit_count: 2,
    hit_interval: 1_000,
    unit_duration: List.duplicate(4_500, 10),
    duration: [2_000, 3_000, 3_000, 4_000, 4_000, 5_000, 5_000, 6_000, 6_000, 7_000],
    sp_cost: [20, 24, 30, 34, 40, 44, 50, 54, 60, 64],
    cast_time: List.duplicate(6_300, 10),
    fixed_cast_time: List.duplicate(1_500, 10),
    after_cast_delay: List.duplicate(1_000, 10),
    cooldown: [2_500, 3_000, 3_500, 4_000, 4_500, 5_000, 5_500, 6_000, 6_500, 7_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @hit_counts [2, 3, 3, 4, 4, 5, 5, 6, 6, 7]

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: %{ignore_land_protector: true},
       interval: definition.hit_interval,
       initial_delay: 700,
       duration: Enum.at(definition.duration, level - 1),
       lifecycle_policy: %LifecyclePolicy{on_caster_loss: :skip_action}
     }}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{center: {x, y}, created_at: created_at, level: level} = group, rng) do
    definition = definition()
    count = Enum.at(@hit_counts, level - 1)
    radius = definition.splash_radius

    schedule =
      for index <- 0..(count - 1) do
        %{
          at: created_at + 700 + index * definition.hit_interval,
          position: {x - radius + rng.(radius * 2 + 1), y - radius + rng.(radius * 2 + 1)}
        }
      end

    {:ok, %{group | state: Map.put(group.state, :meteor_schedule, schedule)}}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{state: %{meteor_schedule: schedule}} = group, now) do
    {due, pending} = Enum.split_with(schedule, &(&1.at <= now))

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} -> Enum.each(due, &impact(group, definition(), caster, &1.position))
      {:error, _reason} -> :ok
    end

    {:ok, %{group | state: %{group.state | meteor_schedule: pending}}}
  end

  @spec impact(Group.t(), struct(), struct(), {integer(), integer()}) :: :ok
  defp impact(group, definition, caster, {x, y} = position) do
    if Storage.land_protected?(group.map_name, x, y) do
      :ok
    else
      group.map_name
      |> Combat.splash_targets(position, definition.splash_radius, group.caster_id)
      |> Enum.each(&hit(group, definition, caster, &1))
    end
  end

  @spec hit(Group.t(), struct(), struct(), {atom(), integer()}) :: :ok
  defp hit(group, definition, caster, {unit_type, target_id}) do
    case Combat.apply_skill_unit_damage(
           caster,
           unit_type,
           target_id,
           group.skill_id,
           group.level,
           definition.element,
           125
         ) do
      :ok ->
        StatusInterpreter.apply_status(unit_type, target_id, :sc_stun,
          val1: group.level,
          duration: Enum.at(definition.unit_duration, group.level - 1),
          success_rate: 3 * group.level
        )

      _ ->
        :ok
    end

    :ok
  end
end
