defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteor do
  @moduledoc """
  Meteor Storm (WZ_METEOR). Drops 2 to 7 meteors over a 3-cell area, one per second, each
  a fire splash that stuns 3% per level.

  Renewal: 125% MATK per meteor, a 4.5 s stun, a 6.3 s cast plus 1.5 s fixed, a 1 s delay,
  and a 2.5 to 7 s cooldown. Pre-renewal: 100% MATK per meteor, a 5 s stun, a 15 s variable
  cast, a 2 to 7 s delay, and no cooldown; its data lists one hit per meteor.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 83,
    name: :wz_meteor,
    requires: [],
    display_name: "Meteor Storm",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :fire,
    splash_radius: 3,
    hit_count: [renewal: 2, pre_renewal: 1],
    hit_interval: 1_000,
    unit_duration: [renewal: List.duplicate(4_500, 10), pre_renewal: List.duplicate(5_000, 10)],
    duration: [2_000, 3_000, 3_000, 4_000, 4_000, 5_000, 5_000, 6_000, 6_000, 7_000],
    sp_cost: [20, 24, 30, 34, 40, 44, 50, 54, 60, 64],
    cast_time: [renewal: List.duplicate(6_300, 10), pre_renewal: List.duplicate(15_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(1_500, 10), pre_renewal: []],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 10),
      pre_renewal: [2000, 3000, 3000, 4000, 4000, 5000, 5000, 6000, 6000, 7000]
    ],
    cooldown: [
      renewal: [2_500, 3_000, 3_500, 4_000, 4_500, 5_000, 5_500, 6_000, 6_500, 7_000],
      pre_renewal: []
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @meteors [2, 3, 3, 4, 4, 5, 5, 6, 6, 7]

  @doc "The number of meteors dropped at `level` (clamped to the table), 2 to 7 in both modes."
  @spec meteor_count(pos_integer()) :: pos_integer()
  def meteor_count(level), do: Enum.at(@meteors, min(level, length(@meteors)) - 1)

  @doc "Renewal deals 125% MATK per impact; classic 100%."
  @spec skill_ratio() :: pos_integer()
  def skill_ratio, do: if(GameMode.mode() == :renewal, do: 125, else: 100)

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()
    idx = min(level, definition.max_level) - 1

    {:ok,
     %{
       cells: [center],
       state: %{ignore_land_protector: true},
       interval: definition.hit_interval,
       initial_delay: 700,
       duration: Enum.at(definition.duration, idx),
       lifecycle_policy: %LifecyclePolicy{on_caster_loss: :skip_action}
     }}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{center: {x, y}, created_at: created_at, level: level} = group, rng) do
    definition = definition()
    count = meteor_count(level)
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
    idx = min(group.level, definition.max_level) - 1

    case Combat.apply_skill_unit_damage(
           caster,
           unit_type,
           target_id,
           group.skill_id,
           group.level,
           definition.element,
           skill_ratio()
         ) do
      :ok ->
        StatusInterpreter.apply_status(unit_type, target_id, :sc_stun,
          val1: group.level,
          duration: Enum.at(definition.unit_duration, idx),
          success_rate: 3 * group.level
        )

      _ ->
        :ok
    end

    :ok
  end
end
