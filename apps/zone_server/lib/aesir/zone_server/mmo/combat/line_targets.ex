defmodule Aesir.ZoneServer.Mmo.Combat.LineTargets do
  @moduledoc """
  Selects living offensive targets on a Bresenham line between two points,
  or an eight-direction lane with explicit length and half-width.

  Shared by line-attack skills (e.g. Spear Stab) so the target filter -
  cell membership, enemy relation, alive check - lives in one place, mirroring
  `SplashTargets` for center+radius shapes.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Returns the `{unit_type, unit_id}` units standing on the line of cells from
  `{sx, sy}` to `{tx, ty}` (inclusive of both ends) that are living enemies of
  `caster`.

  With both `:length` and `:width`, selects an eight-direction lane from the
  origin toward the endpoint instead. Without them, uses the original line.
  The spatial query covers the greatest Manhattan distance of the chosen cells.
  """
  @spec select(String.t(), {integer(), integer()}, {integer(), integer()}, map(), keyword()) ::
          [Ref.t()]
  def select(map_name, {sx, sy} = from, {tx, ty} = to, caster, opts \\ []) do
    cell_set =
      case {Keyword.fetch(opts, :length), Keyword.fetch(opts, :width)} do
        {{:ok, length}, {:ok, width}} -> Geometry.path_cells(from, to, length, width)
        _ -> sx |> Geometry.line_cells(sy, tx, ty) |> MapSet.new()
      end

    radius = Enum.max_by(cell_set, fn {x, y} -> Geometry.manhattan_distance(sx, sy, x, y) end)
    {rx, ry} = radius
    radius = Geometry.manhattan_distance(sx, sy, rx, ry)

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
