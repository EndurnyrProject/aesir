defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzStormgust do
  @moduledoc """
  Storm Gust (WZ_STORMGUST). Ground-targeted persistent skill-unit.

  The cast itself deals no damage: as a `target_type: :ground` skill, `use Skill`
  auto-derives a `cast/4` that places this skill's ground unit at the target cell.
  The unit's 5x5 water field then ticks every `hit_interval` ms for its lifetime
  (`Skill.Ground` callbacks below). Each tick resolves the caster's combatant once,
  hits every offensive target inside the footprint with renewal magic damage
  (`Combat.MagicDamageCalculator`, MATK/MDEF/water), knocks each target back, and
  accumulates a per-group hit counter; on a target's 3rd accumulated hit it
  applies Freeze. Matching rAthena the counter is never reset, so it carries
  across overlapping casts. If the caster is gone (logged out/dead) the field
  still ticks and expires but deals no damage that tick. SP and cooldown are
  deducted by the interpreter from the definition.

  rAthena (`skill_db` id 89): `Layout: 4` (filled 5x5), `Interval: 450`,
  `Knockback: 2`, `Element: Water`, `Status: Freeze`, unit lifetime
  `Duration1: 4500`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 89,
    name: :wz_stormgust,
    display_name: "Storm Gust",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    range: 9,
    element: :water,
    knockback: 2,
    splash_radius: 2,
    hit_interval: 450,
    unit_duration: List.duplicate(4_500, 10),
    sp_cost: List.duplicate(78, 10),
    cast_time: [4500, 4700, 4900, 5100, 5300, 5500, 5700, 5900, 6100, 6300],
    after_cast_delay: List.duplicate(1000, 10),
    cooldown: List.duplicate(6000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  # rAthena freezes a target on its 3rd accumulated hit; the counter never resets.
  @freeze_threshold 3

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, definition.splash_radius),
       state: %{hit_counts: %{}},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def on_interval(%Group{center: {cx, cy} = center, map_name: map_name} = group, _now) do
    definition = definition()

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        updated_counts =
          map_name
          |> Combat.splash_targets(center, definition.splash_radius, group.caster_id)
          |> Enum.reduce(group.state.hit_counts, fn {unit_type, target_id}, counts ->
            hit(group, definition, caster, unit_type, target_id, cx, cy)
            bump_and_maybe_freeze(counts, unit_type, target_id)
          end)

        {:ok, %{group | state: %{group.state | hit_counts: updated_counts}}}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  @spec hit(Group.t(), struct(), struct(), atom(), integer(), integer(), integer()) :: :ok
  defp hit(%Group{} = group, definition, caster, unit_type, target_id, cx, cy) do
    Combat.apply_skill_unit_damage(
      caster,
      unit_type,
      target_id,
      group.skill_id,
      group.level,
      definition.element,
      skill_ratio(group.level)
    )

    Combat.knockback(unit_type, target_id, cx, cy, definition.knockback)
    :ok
  end

  # rAthena renewal `WZ_STORMGUST` ratio (`skills/mage/stormgust.cpp:21`):
  # base_skillratio (100) - 30 + 50 * skill_lv.
  @spec skill_ratio(non_neg_integer()) :: non_neg_integer()
  defp skill_ratio(level), do: 70 + 50 * level

  @spec bump_and_maybe_freeze(map(), atom(), integer()) :: map()
  defp bump_and_maybe_freeze(counts, unit_type, target_id) do
    count = Map.get(counts, target_id, 0) + 1

    if count == @freeze_threshold do
      StatusInterpreter.apply_status(unit_type, target_id, :sc_freeze, [])
    end

    Map.put(counts, target_id, count)
  end
end
