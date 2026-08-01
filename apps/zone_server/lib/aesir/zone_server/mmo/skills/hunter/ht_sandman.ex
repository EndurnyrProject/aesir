defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSandman do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 119,
    name: :ht_sandman,
    display_name: "Sandman",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 3,
    splash_radius: 2,
    hit_interval: 1_000,
    unit_duration: [150_000, 120_000, 90_000, 60_000, 30_000],
    sp_cost: List.duplicate(12, 5),
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level, caster_type: type, caster_id: id} = group) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(type, id)

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       visibility: :none
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover), do: trigger(group, mover), else: {:ok, group}
  end

  defp trigger(group, {mover_type, mover_id}) do
    with {:ok, caster} <- Combat.resolve_combatant(group.caster_type, group.caster_id),
         {:ok, {x, y, _map}} <- SpatialIndex.get_unit_position(mover_type, mover_id) do
      group.map_name
      |> Combat.splash_targets({x, y}, definition().splash_radius, caster)
      |> Enum.filter(&Trap.enemy?(group, &1))
      |> Enum.each(&apply_sleep(&1, group))

      :expire
    else
      _ -> {:ok, group}
    end
  end

  defp apply_sleep({unit_type, unit_id}, group) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_sleep,
      duration: 18_000,
      success_rate: 40 + group.level * 10,
      caster_id: group.caster_id,
      source_type: group.caster_type
    )
  end
end
