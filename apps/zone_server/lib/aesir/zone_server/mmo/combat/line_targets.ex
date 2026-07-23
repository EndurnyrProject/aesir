defmodule Aesir.ZoneServer.Mmo.Combat.LineTargets do
  @moduledoc """
  Selects the valid offensive targets standing on the straight line of cells
  between two points.

  Shared by line-attack skills (e.g. Spear Stab) so the target filter -
  cell membership, enemy relation, alive check - lives in one place, mirroring
  `SplashTargets` for center+radius shapes.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Returns the `{unit_type, unit_id}` units standing on the line of cells from
  `{sx, sy}` to `{tx, ty}` (inclusive of both ends) that are living enemies of
  `caster`.

  The spatial index filters by Manhattan distance; since the line's cells
  march monotonically toward `{tx, ty}`, none of them is farther from
  `{sx, sy}` than the endpoint itself, so a single Manhattan-radius query from
  the caster's cell covers the whole line.
  """
  @spec select(String.t(), {integer(), integer()}, {integer(), integer()}, map()) ::
          [{atom(), integer()}]
  def select(map_name, {sx, sy}, {tx, ty}, caster) do
    cell_set = sx |> Geometry.line_cells(sy, tx, ty) |> MapSet.new()
    radius = Geometry.manhattan_distance(sx, sy, tx, ty)

    map_name
    |> SpatialIndex.get_all_units_in_range(sx, sy, radius)
    |> Enum.filter(fn target_ref ->
      CombatTarget.combat_unit?(target_ref) and
        target_ref != {caster.unit_type, caster.unit_id} and
        offensive_target_on_line?(caster, target_ref, cell_set)
    end)
  end

  defp offensive_target_on_line?(caster, {unit_type, target_id}, cell_set) do
    case TargetResolver.resolve(unit_type, target_id) do
      {:ok, _pid, target_state, _target_type} ->
        target = target_state.__struct__.to_combatant(target_state)

        Unit.living?(target_state) and
          Targeting.validate_enemy(caster, target) == :ok and
          on_line?(target_state, cell_set)

      _ ->
        false
    end
  end

  defp on_line?(%{x: x, y: y}, cell_set), do: MapSet.member?(cell_set, {x, y})
end
