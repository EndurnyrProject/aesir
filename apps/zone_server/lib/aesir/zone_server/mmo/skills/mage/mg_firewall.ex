defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFirewall do
  @moduledoc """
  Fire Wall (MG_FIREWALL). Ground-targeted skill-unit laid as a wall of cells.

  As a `target_type: :ground` skill, `use Skill` auto-derives the `cast/4` that
  places this unit at the target cell. The wall is a 3-cell line (renewal) laid
  perpendicular to the caster->target facing: `on_place` reads the caster's cell
  from the group's `origin`, takes the sign of the origin->center vector as the
  facing, rotates it 90 degrees and lays the line through the center along that axis.

  Unlike a per-target counter, the wall shares a single hit budget of `4 + level`
  hits across all of its cells. Each tick the unit hits every offensive target in
  the footprint for half the caster's magic attack in fire and knocks the target
  back two cells unless its defense element is fire or it is undead, decrementing
  the shared budget by one per hit and stopping once the budget is spent. The unit
  expires the moment the budget reaches zero. If the caster is gone the wall still
  ticks but deals no damage and spends no budget that tick. SP and cooldown are
  deducted by the interpreter from the definition.

  Renewal and pre-renewal agree on everything the wall does: same footprint, same
  hit budget, same half-strength fire hit, same knockback rule, and the same
  duration ladder from 5 seconds at level 1 to 14 seconds at level 10.

  The only difference is the cast. Renewal splits it into a variable part that
  falls from 1.6 seconds to 0.56 and a fixed part that only gear and buffs can
  shorten; pre-renewal has no fixed part and a single variable cast that falls
  from 2 seconds to 0.65.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 18,
    name: :mg_firewall,
    requires: [],
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
    cast_time: [
      renewal: [1600, 1440, 1280, 1120, 960, 880, 800, 720, 640, 560],
      pre_renewal: [2000, 1850, 1700, 1550, 1400, 1250, 1100, 950, 800, 650]
    ],
    fixed_cast_time: [400, 360, 320, 280, 240, 220, 200, 180, 160, 140],
    sp_cost: List.duplicate(40, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Unit.SpatialIndex

  # Each hit lands at half the caster's magic attack, in both modes.
  @skill_ratio 50

  # The wall never reaches past one cell from its center, in any facing, so a
  # radius-1 square bounds the occupants worth testing against its cells.
  @wall_half 1

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level} = group) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.wall(center, facing(group)),
       state: %{hits_remaining: 4 + level},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: 3}
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
          |> Enum.filter(&on_wall?(&1, group))
          |> Enum.reduce_while(
            group.state.hits_remaining,
            &spend(&1, &2, group, definition, caster, cx, cy)
          )

        finish(group, remaining)

      {:error, _reason} ->
        {:ok, group}
    end
  end

  # The square the splash query covers is a superset of the wall: on a cardinal
  # facing it includes the two rows beside the line, and on a diagonal the two
  # corners the staircase skips. Only an occupant standing on a wall cell burns.
  @spec on_wall?({atom(), integer()}, Group.t()) :: boolean()
  defp on_wall?({unit_type, unit_id}, %Group{cells: cells}) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, _map_name}} -> {x, y} in cells
      {:error, :not_found} -> false
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
      @skill_ratio,
      base_distance: definition.knockback,
      origin: {cx, cy},
      native_enabled: knockback?(target_id)
    )

    :ok
  end

  # No knockback against a fire-element or undead target.
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

  # The 8-way direction the caster looked along, as the sign of the origin->center
  # vector; the layout turns it into the perpendicular footprint. The origin is
  # read from the group (stamped at placement) because on_place runs inside the
  # caster's own session process, where a caster lookup deadlocks. A caster
  # standing on the center, or a group with no origin, has no facing and gets the
  # layout's default wall.
  @spec facing(Group.t()) :: {integer(), integer()}
  defp facing(%Group{center: {cx, cy}, origin: {px, py}}), do: {sign(cx - px), sign(cy - py)}

  defp facing(%Group{origin: nil}), do: {0, 0}

  @spec sign(integer()) :: -1 | 0 | 1
  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0
end
