defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcGroundattack do
  @moduledoc """
  NPC Ground Attack (NPC_GROUNDATTACK), a mob-cast Earth ground shockwave.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this unit at the target cell through `Skill.Unit.place/4` - the mob
  `MobSkill.Executor` centers that cell on the row's resolved target before
  dispatch, so mob casters need no bespoke placement path. The field deals
  renewal magic damage (`Combat.apply_skill_unit_damage`, MATK/MDEF/earth)
  every `hit_interval` to every living enemy standing in its footprint, same
  pipeline and timing (450ms/4500ms unit, 70 + 50 * level ratio) as every
  other mob ground shockwave.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 185,
    name: :npc_groundattack,
    display_name: "NPC Ground Attack",
    max_level: 9,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    element: :earth,
    splash_radius: 2,
    hit_interval: 450,
    unit_duration: List.duplicate(4_500, 9)

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, map_name: map_name, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: walkable_footprint(map_name, center, definition.splash_radius),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def on_interval(%Group{center: center, map_name: map_name} = group, _now) do
    definition = definition()

    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        map_name
        |> Combat.splash_targets(center, definition.splash_radius, caster)
        |> Enum.each(&hit(group, definition, caster, &1))

        {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  @spec hit(Group.t(), struct(), struct(), {atom(), integer()}) :: :ok
  defp hit(%Group{} = group, definition, caster, {unit_type, target_id}) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      group.skill_id,
      group.level,
      definition.element,
      skill_ratio(group.level)
    )

    :ok
  end

  @spec skill_ratio(non_neg_integer()) :: non_neg_integer()
  defp skill_ratio(level), do: 70 + 50 * level

  @spec walkable_footprint(String.t(), Group.cell(), non_neg_integer()) :: [Group.cell()]
  defp walkable_footprint(map_name, center, radius) do
    center
    |> Layout.square(radius)
    |> Enum.filter(fn {x, y} -> Cell.traversable?(map_name, x, y) end)
  end
end
