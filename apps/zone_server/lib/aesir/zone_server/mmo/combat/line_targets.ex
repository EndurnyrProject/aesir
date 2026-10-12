defmodule Aesir.ZoneServer.Mmo.Combat.LineTargets do
  @moduledoc """
  Selects living offensive targets on a Bresenham line between two points,
  or an eight-direction lane with explicit length and half-width.

  Shared by line-attack skills (e.g. Spear Stab) so the target filter -
  cell membership, enemy relation, alive check - lives in one place, mirroring
  `SplashTargets` for center+radius shapes.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.LineOfSight
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
  origin toward the endpoint instead, starting `:offset` rows out (default 0),
  and keeps only the units the origin has a clear line of sight to. Without
  them, uses the original line. The spatial query covers the greatest
  Manhattan distance of the chosen cells.
  """
  @spec select(String.t(), {integer(), integer()}, {integer(), integer()}, map(), keyword()) ::
          [Ref.t()]
  def select(map_name, {sx, sy} = from, {tx, ty} = to, caster, opts \\ []) do
    {cell_set, sighted?} =
      case {Keyword.fetch(opts, :length), Keyword.fetch(opts, :width)} do
        {{:ok, length}, {:ok, width}} ->
          offset = Keyword.get(opts, :offset, 0)

          {Geometry.path_cells(from, to, length, width, offset),
           &LineOfSight.clear?(map_name, from, &1)}

        _ ->
          {sx |> Geometry.line_cells(sy, tx, ty) |> MapSet.new(), fn _cell -> true end}
      end

    radius = Enum.max_by(cell_set, fn {x, y} -> Geometry.manhattan_distance(sx, sy, x, y) end)
    {rx, ry} = radius
    radius = Geometry.manhattan_distance(sx, sy, rx, ry)

    map_name
    |> SpatialIndex.get_all_units_in_range(sx, sy, radius)
    |> Enum.filter(fn target_ref ->
      CombatTarget.combat_unit?(target_ref) and
        target_ref != {caster.unit_type, caster.unit_id} and
        offensive_target_on_line?(caster, target_ref, cell_set, sighted?)
    end)
  end

  defp offensive_target_on_line?(caster, {unit_type, target_id}, cell_set, sighted?) do
    case TargetResolver.resolve(unit_type, target_id) do
      {:ok, _pid, %{x: x, y: y} = target_state, _target_type} ->
        target = target_state.__struct__.to_combatant(target_state)

        Unit.living?(target_state) and
          Targeting.validate_enemy(caster, target) == :ok and
          MapSet.member?(cell_set, {x, y}) and sighted?.({x, y})

      _ ->
        false
    end
  end
end
