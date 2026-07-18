defmodule Aesir.ZoneServer.Mmo.Skills.MgFirewall do
  @moduledoc """
  Fire Wall (MG_FIREWALL). Ground-targeted skill-unit laid as a wall of cells.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this unit at the target cell. The wall is a 3-cell line (renewal) laid
  perpendicular to the caster->target facing: `on_place` reads the caster's cell
  from the group's `origin`, takes the sign of the origin->center vector as the
  facing, rotates it 90 degrees and lays the line through the center along that axis.

  Unlike a per-target counter, the wall shares a single hit budget of `4 + level`
  hits across all of its cells (rAthena `skill_unit_group->val2`). Each tick the
  unit hits every offensive target in the footprint with 50% renewal fire magic
  damage (`Combat.MagicDamageCalculator`, MATK/MDEF/fire) and knocks the target
  back two cells unless its defense element is fire or it is undead, decrementing
  the shared budget by one per hit and stopping once the budget is spent. The unit
  expires the moment the budget reaches zero. If the caster is gone the wall still
  ticks but deals no damage and spends no budget that tick. SP and cooldown are
  deducted by the interpreter from the definition.

  rAthena (`skill_db` id 18): renewal 3 cells, `Element: Fire`, ratio
  `base_skillratio (100) - 50`, `Knockback: 2`, hit budget `4 + skill_lv`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 18,
    name: :mg_firewall,
    display_name: "Fire Wall",
    max_level: 10,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :fire,
    knockback: 2,
    hit_interval: 20,
    unit_duration: [5000, 6000, 7000, 8000, 9000, 10_000, 11_000, 12_000, 13_000, 14_000],
    cast_time: [1600, 1440, 1280, 1120, 960, 880, 800, 720, 640, 560],
    fixed_cast_time: [400, 360, 320, 280, 240, 220, 200, 180, 160, 140],
    sp_cost: List.duplicate(40, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout

  # Renewal MG_FIREWALL ratio: base_skillratio (100) - 50.
  @skill_ratio 50

  # Renewal wall is three cells (half-length 1 around the center).
  @wall_half 1

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level} = group) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.line(center, wall_direction(group), @wall_half),
       state: %{hits_remaining: 4 + level},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def on_interval(%Group{center: {cx, cy} = center, map_name: map_name} = group, _now) do
    definition = definition()

    case Combat.resolve_combatant(group.caster_id) do
      {:ok, caster} ->
        remaining =
          map_name
          |> Combat.splash_targets(center, @wall_half, group.caster_id)
          |> Enum.reduce_while(
            group.state.hits_remaining,
            &spend(&1, &2, group, definition, caster, cx, cy)
          )

        finish(group, remaining)

      {:error, _reason} ->
        {:ok, group}
    end
  end

  # Spends one shared-budget hit per target, stopping the fold once it runs out.
  @spec spend(
          {atom(), integer()},
          non_neg_integer(),
          Group.t(),
          struct(),
          struct(),
          integer(),
          integer()
        ) :: {:cont, non_neg_integer()} | {:halt, 0}
  defp spend(_target, 0, _group, _definition, _caster, _cx, _cy), do: {:halt, 0}

  defp spend({unit_type, target_id}, budget, group, definition, caster, cx, cy) do
    hit(group, definition, caster, unit_type, target_id, cx, cy)
    {:cont, budget - 1}
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
      @skill_ratio
    )

    if knockback?(target_id) do
      Combat.knockback(unit_type, target_id, cx, cy, definition.knockback)
    end

    :ok
  end

  # No knockback against a fire-element or undead target (rAthena skill_blown guard).
  @spec knockback?(integer()) :: boolean()
  defp knockback?(target_id) do
    case Combat.resolve_combatant(target_id) do
      {:ok, %{race: race, element: element}} ->
        not (RaceModifiers.undead?(race) or immune_element?(element))

      {:error, _reason} ->
        true
    end
  end

  @spec immune_element?(tuple() | atom()) :: boolean()
  defp immune_element?({element, _level}), do: element in [:fire, :undead]
  defp immune_element?(element), do: element in [:fire, :undead]

  @spec finish(Group.t(), non_neg_integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  defp finish(%Group{state: state} = group, remaining) do
    updated = %{group | state: %{state | hits_remaining: remaining}}
    if remaining <= 0, do: {:expire, updated}, else: {:ok, updated}
  end

  # The wall lies perpendicular to the caster->center facing. We take the sign of
  # the origin->center vector as the facing (8-dir), rotate it 90 degrees
  # ({fx, fy} -> {-fy, fx}) and lay the line along the result. A caster standing
  # on the center has no facing, so we default to a horizontal (east-west) wall.
  # The origin is read from the group (stamped at placement) because on_place
  # runs inside the caster's own session process, where a caster lookup deadlocks.
  @spec wall_direction(Group.t()) :: {integer(), integer()}
  defp wall_direction(%Group{center: {cx, cy}, origin: {px, py}}) do
    case {sign(cx - px), sign(cy - py)} do
      {0, 0} -> {1, 0}
      {fx, fy} -> {-fy, fx}
    end
  end

  defp wall_direction(%Group{origin: nil}), do: {1, 0}

  @spec sign(integer()) :: -1 | 0 | 1
  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0
end
