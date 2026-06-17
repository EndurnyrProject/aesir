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

  @radius 2
  @interval 450
  # rAthena WZ_STORMGUST Duration1
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
  def on_interval(%Group{center: {cx, cy} = center, map_name: map_name} = group, _now) do
    updated_counts =
      map_name
      |> Combat.splash_targets(center, @radius, group.caster_id)
      |> Enum.reduce(group.state.hit_counts, fn {unit_type, target_id}, counts ->
        hit(group, unit_type, target_id, cx, cy)
        bump_and_maybe_freeze(counts, unit_type, target_id)
      end)

    {:ok, %{group | state: %{group.state | hit_counts: updated_counts}}}
  end

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
