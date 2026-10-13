defmodule Aesir.ZoneServer.Mmo.Skill.Unit.UnitTimer do
  @moduledoc """
  The per-cell pass of interval ground fields, run by `Skill.Unit.Manager` on
  every tick.

  A group with a `unit_range` acts as one unit per footprint cell. A pass walks
  every live cell of every such group in skill-unit table order (`order/1`).
  A cell under Land Protector does nothing unless its group ignores Land
  Protector. Otherwise the cell offers its group the combat units within
  `unit_range` cells of it (Chebyshev square, line of sight from the cell when
  the group path-checks) whose strike interval has run out; the group keeps the
  ones it may affect (`unit_targets/3`) and strikes each once
  (`on_unit_hit/4`), and that unit's next strike moves to `now + interval`.

  The strike interval is tracked per unit and keyed by skill for a `no_overlap`
  group, so overlapping groups of one skill strike a unit once per interval
  between them, and by group otherwise. A unit first reached mid-interval is
  struck on the next pass. A unit the group does not keep does not spend its
  interval.

  An `on_unit_hit/4` returning `{:expire, group}` still strikes the rest of
  that cell's units; the group's later cells do nothing and the manager ends
  it after the pass.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @table_buckets 283

  @typedoc "One unit's strike interval for one skill (NoOverlap) or one group."
  @type tickset_key :: {Ref.t(), {:skill, integer()} | {:group, integer()}}

  @typedoc "The earliest time each unit may be struck again."
  @type ticksets :: %{tickset_key() => integer()}

  @typedoc "Invokes a group callback the way the manager does."
  @type invoke :: (module(), atom(), list() -> {:ok, term()} | {:error, term()})

  @typedoc "How a group left the pass."
  @type outcome :: :ok | :expire | {:failed, atom(), term()}

  @doc """
  Orders cells as the skill-unit table iterates them: by id remainder over its
  283 buckets, then by id.
  """
  @spec order([Cell.t()]) :: [Cell.t()]
  def order(cells), do: Enum.sort_by(cells, &{rem(&1.cell_id, @table_buckets), &1.cell_id})

  @doc """
  Runs one pass over `fields` (`{group, module}` pairs) at `now`.

  Returns every group as it left the pass with its outcome, and the updated
  strike intervals.
  """
  @spec run([{Group.t(), module()}], ticksets(), integer(), invoke()) ::
          {[{Group.t(), module(), outcome()}], ticksets()}
  def run(fields, ticksets, now, invoke) do
    ticksets = Map.reject(ticksets, fn {_key, next} -> next <= now end)
    by_id = Map.new(fields, fn {group, module} -> {group.group_id, {group, module, :ok}} end)

    {by_id, ticksets} =
      fields
      |> Enum.flat_map(fn {group, _module} -> Storage.get_cells_by_group(group.group_id) end)
      |> order()
      |> Enum.reduce({by_id, ticksets}, fn cell, acc -> run_cell(cell, acc, now, invoke) end)

    {Map.values(by_id), ticksets}
  end

  defp run_cell(%Cell{group_id: group_id} = cell, {by_id, ticksets} = acc, now, invoke) do
    case Map.fetch(by_id, group_id) do
      {:ok, {group, module, :ok}} ->
        if protected?(group, cell) do
          acc
        else
          {entry, ticksets} = strike_cell(group, module, {cell.x, cell.y}, ticksets, now, invoke)
          {Map.put(by_id, group_id, entry), ticksets}
        end

      _ended ->
        acc
    end
  end

  defp protected?(group, %Cell{x: x, y: y}) do
    not Group.ignores_land_protector?(group) and Storage.land_protected?(group.map_name, x, y)
  end

  defp strike_cell(group, module, cell, ticksets, now, invoke) do
    due = Enum.filter(reached(group, cell), &(Map.get(ticksets, key(group, &1), now) <= now))

    case due do
      [] ->
        {{group, module, :ok}, ticksets}

      refs ->
        case invoke.(module, :unit_targets, [group, cell, refs]) do
          {:ok, kept} when is_list(kept) ->
            strike_targets(
              group,
              module,
              cell,
              Enum.filter(refs, &(&1 in kept)),
              ticksets,
              now,
              invoke
            )

          {:ok, other} ->
            {{group, module, {:failed, :unit_targets, {:invalid_return, other}}}, ticksets}

          {:error, reason} ->
            {{group, module, {:failed, :unit_targets, reason}}, ticksets}
        end
    end
  end

  defp strike_targets(group, module, cell, refs, ticksets, now, invoke) do
    Enum.reduce_while(refs, {{group, module, :ok}, ticksets}, fn ref,
                                                                 {{group, _, outcome}, ticksets} ->
      ticksets = Map.put(ticksets, key(group, ref), now + group.interval)

      case invoke.(module, :on_unit_hit, [group, cell, ref, now]) do
        {:ok, {:ok, %Group{group_id: id} = updated}} when id == group.group_id ->
          {:cont, {{updated, module, outcome}, ticksets}}

        {:ok, {:expire, %Group{group_id: id} = updated}} when id == group.group_id ->
          {:cont, {{updated, module, :expire}, ticksets}}

        {:ok, other} ->
          {:halt, {{group, module, {:failed, :on_unit_hit, {:invalid_return, other}}}, ticksets}}

        {:error, reason} ->
          {:halt, {{group, module, {:failed, :on_unit_hit, reason}}, ticksets}}
      end
    end)
  end

  defp reached(%Group{map_name: map_name, unit_range: range} = group, {x, y} = cell) do
    map_name
    |> SpatialIndex.get_all_units_in_range(x, y, range * 2)
    |> Enum.filter(fn {unit_type, unit_id} = ref ->
      CombatTarget.combat_unit?(ref) and
        case SpatialIndex.get_unit_position(unit_type, unit_id) do
          {:ok, {tx, ty, ^map_name}} ->
            Geometry.chebyshev_distance(x, y, tx, ty) <= range and
              (not group.path_check or LineOfSight.clear?(map_name, cell, {tx, ty}))

          _elsewhere ->
            false
        end
    end)
  end

  defp key(%Group{no_overlap: true, skill_id: skill_id}, ref), do: {ref, {:skill, skill_id}}
  defp key(%Group{group_id: group_id}, ref), do: {ref, {:group, group_id}}
end
