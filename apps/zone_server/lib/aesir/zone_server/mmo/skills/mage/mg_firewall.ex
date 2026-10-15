defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFirewall do
  @moduledoc """
  Fire Wall (MG_FIREWALL). Ground-targeted skill-unit laid as a wall of cells.

  The wall is laid across the direction the caster looks toward the target cell
  (rAthena's eight sectors; a caster on the target cell looks east): three cells
  on a cardinal direction, a five-cell staircase on a diagonal. Cells on walls or
  without a straight line to the caster are not laid.

  Each cell is its own unit with its own budget of `4 + level` strikes. On every
  100 ms unit pass a cell burns each enemy standing on it whose 20 ms strike
  interval ran out, up to five times in a row while the enemy stays on the cell
  and lives, each strike spending one of that cell's budget. A cell whose budget
  runs out burns out at once; the rest of the wall stays. Each strike is a fire
  hit at half the caster's magic attack that knocks the target two cells straight
  back from where it faces, unless its defense element is fire or undead. A cell
  on Land Protector burns nobody. Nothing burns while the caster is gone.

  The wall lasts 5 s at level 1 up to 14 s at level 10, half again as long when
  the caster stands in Violent Gale. A player keeps at most three walls: a
  fourth cast fails before anything is spent, already when it starts. Renewal
  and pre-renewal agree on everything the wall does.

  The only difference is the cast. Renewal splits it into a variable part that
  falls from 1.6 seconds to 0.56 and a fixed part that only gear and buffs can
  shorten; pre-renewal has no fixed part and a single variable cast that falls
  from 2 seconds to 0.65.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 18,
    name: :mg_firewall,
    active_instance: 3,
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

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Each hit lands at half the caster's magic attack, in both modes.
  @skill_ratio 50

  # Aesir's sprite-frame direction for north (`Geometry.calculate_direction/4`).
  @north 4

  @behaviour Ground

  @impl Ground
  def on_place(%Group{center: center, level: level} = group) do
    definition = definition()
    cells = Layout.wall(center, facing(group))

    {:ok,
     %{
       cells: cells,
       state: %{cell_budget: Map.new(cells, &{&1, 4 + level})},
       interval: definition.hit_interval,
       duration: duration(group, Enum.at(definition.unit_duration, level - 1)),
       unit_range: 0,
       path_check: true
     }}
  end

  @impl Ground
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def unit_targets(%Group{} = group, _cell, refs) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} -> SplashTargets.eligible(refs, caster)
      {:error, _reason} -> []
    end
  end

  @impl Ground
  def on_unit_hit(%Group{state: %{cell_budget: budgets} = state} = group, cell, target, _now) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} ->
        strikes = div(Manager.tick_interval(), group.interval)
        left = burn(group, caster, target, Map.fetch!(budgets, cell), strikes, 0)
        group = %{group | state: %{state | cell_budget: Map.put(budgets, cell, left)}}

        if left <= 0,
          do: {:ok, group, [{:remove_cells, group.group_id, [cell]}]},
          else: {:ok, group}

      {:error, _reason} ->
        {:ok, group}
    end
  end

  # Strikes again while the cell has budget and strikes left this pass and the
  # target was neither killed nor moved. Each strike spends one budget, even one
  # the target was not open to.
  defp burn(group, caster, target, budget, strikes, prior_damage) do
    report = strike(group, caster, target, prior_damage)
    budget = budget - 1

    if budget > 0 and strikes > 1 and report.survives? and not report.moved?,
      do: burn(group, caster, target, budget, strikes - 1, prior_damage + report.damage),
      else: budget
  end

  defp strike(%Group{} = group, caster, {unit_type, target_id} = target, prior_damage) do
    definition = definition()

    case Combat.apply_skill_unit_damage(
           caster,
           unit_type,
           target_id,
           group.skill_id,
           group.level,
           definition.element,
           @skill_ratio,
           base_distance: definition.knockback,
           origin: ahead_of(target),
           native_enabled: knockback?(target),
           report_hit: true,
           prior_damage: prior_damage
         ) do
      {:ok, report} -> report
      _refused -> %{damage: 0, survives?: true, moved?: false}
    end
  end

  # The push origin sits one cell ahead of the target's facing, so the blow
  # travels straight back. A unit without a facing faces north.
  defp ahead_of({unit_type, unit_id}) do
    with {:ok, {x, y, _map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(unit_type, unit_id) do
      {dx, dy} = Geometry.facing_delta(Map.get(state, :dir, @north))
      {x + dx, y + dy}
    else
      _gone -> nil
    end
  end

  # No knockback against a fire-element or undead-element target.
  defp knockback?({unit_type, unit_id}) do
    case Combat.resolve_combatant(unit_type, unit_id) do
      {:ok, target} -> not (fire?(target.element) or RaceModifiers.undead_target?(target))
      {:error, _reason} -> true
    end
  end

  defp fire?({element, _level}), do: element == :fire
  defp fire?(element), do: element == :fire

  defp duration(%Group{caster_type: type, caster_id: id}, duration) do
    if StatusStorage.has_status?(type, id, :sc_violentgale),
      do: div(duration * 3, 2),
      else: duration
  end

  # The direction the caster looks toward the center by rAthena's eight
  # sectors, read from the group's origin (stamped at placement) because
  # on_place runs inside the caster's own session process, where a caster
  # lookup deadlocks. A caster on the center looks east.
  @spec facing(Group.t()) :: {integer(), integer()}
  defp facing(%Group{center: {cx, cy}, origin: {px, py}}),
    do: Geometry.sector_step(cx - px, cy - py)

  defp facing(%Group{origin: nil}), do: Geometry.sector_step(0, 0)
end
