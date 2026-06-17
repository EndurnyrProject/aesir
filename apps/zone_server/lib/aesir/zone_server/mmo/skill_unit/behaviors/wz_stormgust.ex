defmodule Aesir.ZoneServer.Mmo.SkillUnit.Behaviors.WzStormgust do
  @moduledoc """
  Storm Gust (WZ_STORMGUST) ground skill-unit.

  A 5x5 (Chebyshev radius 2) water field that ticks every 450ms for its lifetime.
  Each tick hits every offensive target inside the footprint once (`HitCount: 1`),
  deals stubbed magic damage (`SkillUnit.Damage.magic_stub/4`), knocks each target
  back 2 cells, and accumulates a per-group hit counter. On a target's 3rd
  accumulated hit it applies Freeze; matching rAthena the counter is never reset,
  so it carries across overlapping casts.

  rAthena (`skill_db` id 89): `Layout: 4` (filled 5x5), `Interval: 450`,
  `Knockback: 2`, `Element: Water`, `Status: Freeze`, unit lifetime
  `Duration1: 4500`.
  """
  use Aesir.ZoneServer.Mmo.SkillUnit.Behaviour

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.SkillUnit.Damage
  alias Aesir.ZoneServer.Mmo.SkillUnit.Group
  alias Aesir.ZoneServer.Mmo.SkillUnit.Layout
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @radius 2
  @interval 450
  @duration 4_500
  @knockback 2
  @freeze_threshold 3
  @element :water

  @impl true
  def skill_name, do: :wz_stormgust

  @impl true
  def on_place(%Group{center: center}) do
    {:ok,
     %{
       cells: Layout.square(center, @radius),
       state: %{hit_counts: %{}},
       interval: @interval,
       duration: @duration
     }}
  end

  @impl true
  def on_interval(%Group{center: {cx, cy}} = group, _now) do
    updated_counts =
      group
      |> footprint_targets()
      |> Enum.reduce(group.state.hit_counts, fn {unit_type, target_id}, counts ->
        hit(group, unit_type, target_id, cx, cy)
        bump_and_maybe_freeze(counts, unit_type, target_id)
      end)

    {:ok, %{group | state: %{group.state | hit_counts: updated_counts}}}
  end

  @spec footprint_targets(Group.t()) :: [{atom(), integer()}]
  defp footprint_targets(%Group{center: {cx, cy}, map_name: map_name}) do
    map_name
    |> SpatialIndex.get_all_units_in_range(cx, cy, @radius * 2)
    |> Enum.filter(&offensive_target?(&1, map_name, cx, cy))
  end

  # Mobs only for now; the caster (a player) and allies are excluded by type.
  defp offensive_target?({:mob, target_id}, map_name, cx, cy) do
    case SpatialIndex.get_unit_position(:mob, target_id) do
      {:ok, {tx, ty, ^map_name}} -> in_square?(cx, cy, tx, ty)
      _ -> false
    end
  end

  defp offensive_target?({:player, _id}, _map_name, _cx, _cy), do: false

  defp in_square?(cx, cy, tx, ty), do: abs(tx - cx) <= @radius and abs(ty - cy) <= @radius

  @spec hit(Group.t(), atom(), integer(), integer(), integer()) :: :ok
  defp hit(%Group{} = group, unit_type, target_id, cx, cy) do
    damage = Damage.magic_stub(group, target_id, group.level, @element)

    Combat.apply_skill_unit_damage(
      group.caster_id,
      unit_type,
      target_id,
      damage,
      group.skill_id,
      group.level
    )

    Combat.knockback(unit_type, target_id, cx, cy, @knockback)
    :ok
  end

  @spec bump_and_maybe_freeze(map(), atom(), integer()) :: map()
  defp bump_and_maybe_freeze(counts, unit_type, target_id) do
    count = Map.get(counts, target_id, 0) + 1

    if count == @freeze_threshold do
      StatusInterpreter.apply_status(unit_type, target_id, :sc_freeze, [])
    end

    Map.put(counts, target_id, count)
  end
end
