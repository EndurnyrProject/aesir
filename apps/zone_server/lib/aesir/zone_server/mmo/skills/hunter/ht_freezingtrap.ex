defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtFreezingtrap do
  @moduledoc """
  Freezing Trap (HT_FREEZINGTRAP), an activator-centered Water weapon trap.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 121,
    name: :ht_freezingtrap,
    display_name: "Freezing Trap",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :weapon,
    element: :water,
    range: 3,
    splash_radius: 1,
    hit_interval: 1_000,
    unit_duration: [150_000, 120_000, 90_000, 60_000, 30_000],
    sp_cost: [10, 10, 10, 10, 10],
    item_cost: [%{id: 1065, amount: 2}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @behaviour Ground
  @freeze_durations [3_000, 6_000, 9_000, 12_000, 15_000]

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level} = group) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, %{dex: 0, int: 0, base_level: 0}, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       visibility: :none
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, {mover_type, mover_id} = mover) do
    if Trap.enemy?(group, mover) do
      fire(group, mover_type, mover_id)
    else
      {:ok, group}
    end
  end

  defp fire(group, mover_type, mover_id) do
    map_name = group.map_name

    with {:ok, caster} <- Trap.resolve_caster(group),
         {:ok, {x, y, ^map_name}} <- SpatialIndex.get_unit_position(mover_type, mover_id) do
      definition = definition()

      hits =
        Combat.execute_splash_attack(caster, {x, y}, definition.splash_radius,
          skill_id: definition.id,
          skill_level: group.level,
          skill_ratio: 100,
          element: :water,
          ignore_flee: true,
          skip_crit: true
        )

      Enum.each(hits, &freeze(group, target_type(group), &1))
      :expire
    else
      _ -> {:ok, group}
    end
  end

  defp freeze(group, unit_type, unit_id) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_freeze,
      duration: Enum.at(@freeze_durations, group.level - 1),
      caster_id: group.caster_id,
      source_type: group.caster_type
    )
  end

  defp target_type(%Group{caster_type: :player}), do: :mob
  defp target_type(%Group{caster_type: :mob}), do: :player
end
