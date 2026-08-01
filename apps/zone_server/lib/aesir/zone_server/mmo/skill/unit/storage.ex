defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Storage do
  @moduledoc """
  ETS-based storage for ground skill-unit groups.

  One `:set` table owns the authoritative `Group` rows. Synchronized ETS indexes
  serve exact coordinate, caster, and target lookups plus due/expiry queries,
  keeping the central tick loop and movement hooks off full group scans.
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  @doc """
  Inserts (or replaces) a group, keyed by its `group_id`.
  """
  @spec insert(Group.t()) :: :ok
  def insert(%Group{group_id: group_id} = group) do
    case get(group_id) do
      nil -> :ok
      old_group -> delete_indexes(old_group)
    end

    store(group)
  end

  @doc """
  Replaces an existing group and all of its secondary keys.

  A no-op when teardown already removed the group.
  """
  @spec update(Group.t()) :: :ok
  def update(%Group{group_id: group_id} = group) do
    case get(group_id) do
      nil ->
        :ok

      old_group ->
        :ok = delete_indexes(old_group)
        store(group)
    end
  end

  defp store(%Group{group_id: group_id} = group) do
    :ets.insert(table_for(:skill_units), {group_id, group})

    :ets.insert(
      table_for(:skill_unit_caster_index),
      {{group.caster_type, group.caster_id}, group_id}
    )

    insert_coordinate_indexes(group)
    insert_timing_indexes(group)
    insert_target_index(group)
    :ok
  end

  @doc """
  Fetches a group by `group_id`, or `nil` when absent.
  """
  @spec get(non_neg_integer()) :: Group.t() | nil
  def get(group_id) do
    case :ets.lookup(table_for(:skill_units), group_id) do
      [{^group_id, group}] -> group
      [] -> nil
    end
  end

  @doc "Stores a cell and its read indexes."
  @spec insert_cell(Cell.t()) :: :ok
  def insert_cell(%Cell{} = cell) do
    case get_cell(cell.cell_id) do
      nil -> :ok
      old_cell -> delete_cell_indexes(old_cell)
    end

    store_cell(cell)
  end

  @doc "Updates an existing cell without resurrecting a removed cell."
  @spec update_cell(Cell.t()) :: :ok
  def update_cell(%Cell{cell_id: cell_id} = cell) do
    case get_cell(cell_id) do
      nil ->
        :ok

      old_cell ->
        :ok = delete_cell_indexes(old_cell)
        store_cell(cell)
    end
  end

  @doc "Fetches a cell by its stable runtime ID."
  @spec get_cell(non_neg_integer()) :: Cell.t() | nil
  def get_cell(cell_id) do
    case :ets.lookup(table_for(:skill_unit_cells), cell_id) do
      [{^cell_id, cell}] -> cell
      [] -> nil
    end
  end

  @doc "Deletes a cell and every secondary key."
  @spec delete_cell(non_neg_integer()) :: :ok
  def delete_cell(cell_id) do
    if cell = get_cell(cell_id), do: delete_cell_indexes(cell)
    :ets.delete(table_for(:skill_unit_cells), cell_id)
    :ok
  end

  @doc "Returns every cell owned by a group."
  @spec get_cells_by_group(non_neg_integer()) :: [Cell.t()]
  def get_cells_by_group(group_id) do
    table_for(:skill_unit_group_cells_index)
    |> :ets.lookup(group_id)
    |> Enum.map(fn {^group_id, cell_id} -> get_cell(cell_id) end)
    |> Enum.reject(&is_nil/1)
  end

  @doc "Returns visible groups whose footprint intersects an inclusive square range."
  @spec get_visible_groups_in_range(String.t(), integer(), integer(), non_neg_integer()) :: [
          Group.t()
        ]
  def get_visible_groups_in_range(map_name, x, y, range) do
    indexed_group_ids_in_range(map_name, x, y, range)
    |> indexed_groups()
    |> Enum.sort_by(& &1.group_id)
  end

  @doc false
  @spec replace_observer_groups(integer(), Enumerable.t()) :: :ok
  def replace_observer_groups(observer_id, group_ids) do
    clear_observer_groups(observer_id)
    Enum.each(group_ids, &add_observer_group(observer_id, &1))
    :ok
  end

  @doc false
  @spec get_observer_groups(integer()) :: MapSet.t(non_neg_integer())
  def get_observer_groups(observer_id) do
    table_for(:skill_unit_observer_groups)
    |> :ets.match({{observer_id, :"$1"}, :_})
    |> MapSet.new(fn [group_id] -> group_id end)
  end

  @doc false
  @spec add_observer_group(integer(), non_neg_integer()) :: :ok
  def add_observer_group(observer_id, group_id) do
    :ets.insert(table_for(:skill_unit_observer_groups), {{observer_id, group_id}, true})
    :ets.insert(table_for(:skill_unit_group_observers), {group_id, observer_id})
    :ok
  end

  @doc false
  @spec remove_observer_group(integer(), non_neg_integer()) :: :ok
  def remove_observer_group(observer_id, group_id) do
    :ets.delete(table_for(:skill_unit_observer_groups), {observer_id, group_id})
    :ets.delete_object(table_for(:skill_unit_group_observers), {group_id, observer_id})
    :ok
  end

  @doc false
  @spec take_group_observers(non_neg_integer()) :: [integer()]
  def take_group_observers(group_id) do
    observers =
      table_for(:skill_unit_group_observers)
      |> :ets.lookup(group_id)
      |> Enum.map(fn {^group_id, observer_id} -> observer_id end)

    Enum.each(observers, &remove_observer_group(&1, group_id))
    observers
  end

  @doc """
  Deletes a group by `group_id`.
  """
  @spec delete(non_neg_integer()) :: :ok
  def delete(group_id) do
    case get(group_id) do
      nil ->
        :ok

      group ->
        delete_indexes(group)
        group.group_id |> get_cells_by_group() |> Enum.each(&delete_cell(&1.cell_id))
    end

    :ets.delete(table_for(:skill_units), group_id)
    :ok
  end

  @doc """
  Drops coordinates from a live group and from every coordinate index.

  Coordinates the group does not own are ignored. Returns the shrunken group,
  which the caller keeps using as the authoritative row.
  """
  @spec remove_cells(Group.t(), [Group.cell()]) :: Group.t()
  def remove_cells(%Group{} = group, cells) do
    removed = MapSet.new(cells)
    shrunken = %{group | cells: Enum.reject(group.cells, &MapSet.member?(removed, &1))}
    :ok = update(shrunken)
    shrunken
  end

  @doc """
  Returns every stored group.
  """
  @spec all() :: [Group.t()]
  def all do
    table_for(:skill_units)
    |> :ets.tab2list()
    |> Enum.map(fn {_group_id, group} -> group end)
  end

  @doc """
  Returns every group whose footprint covers cell `(x, y)` on `map_name`.

  Used by the movement-pipeline `on_touch` hook to find ground units a mover
  just stepped onto.
  """
  @spec get_groups_at_cell(String.t(), integer(), integer()) :: [Group.t()]
  def get_groups_at_cell(map_name, x, y) do
    :skill_unit_coordinate_index
    |> table_for()
    |> :ets.lookup({map_name, x, y})
    |> Enum.map(fn {_coordinate, group_id} -> group_id end)
    |> indexed_groups()
  end

  @doc "Whether a Land Protector footprint covers cell `(x, y)` on `map_name`."
  @spec land_protected?(String.t(), integer(), integer()) :: boolean()
  def land_protected?(map_name, x, y) do
    map_name |> get_groups_at_cell(x, y) |> Enum.any?(&Group.land_protector?/1)
  end

  @doc "Returns every group owned by the given caster."
  @spec get_groups_by_caster(atom(), integer()) :: [Group.t()]
  def get_groups_by_caster(caster_type, caster_id) do
    indexed_groups(:skill_unit_caster_index, caster_type, caster_id)
  end

  @doc "Returns every group for a skill owned by the given caster."
  @spec get_groups_by_skill_and_caster(atom(), atom(), integer()) :: [Group.t()]
  def get_groups_by_skill_and_caster(skill_name, caster_type, caster_id) do
    caster_type
    |> get_groups_by_caster(caster_id)
    |> Enum.filter(&(&1.skill_name == skill_name))
  end

  @doc "Returns every group associated with the given optional target."
  @spec get_groups_by_target(atom(), integer()) :: [Group.t()]
  def get_groups_by_target(target_type, target_id) do
    indexed_groups(:skill_unit_target_index, target_type, target_id)
  end

  @doc """
  Returns groups whose `next_tick_at <= now_ms` (due for an interval tick).
  """
  @spec get_due_groups(integer()) :: [Group.t()]
  def get_due_groups(now_ms) do
    groups_due_for(:due, now_ms)
  end

  @doc """
  Returns groups whose `expires_at <= now_ms` (ready to be reaped).
  """
  @spec get_expired_groups(integer()) :: [Group.t()]
  def get_expired_groups(now_ms) do
    groups_due_for(:expiry, now_ms)
  end

  defp insert_coordinate_indexes(%Group{} = group) do
    Enum.each(group.cells, fn {x, y} ->
      :ets.insert(
        table_for(:skill_unit_coordinate_index),
        {{group.map_name, x, y}, group.group_id}
      )
    end)

    if Group.materialized?(group) do
      Enum.each(group.cells, fn {x, y} ->
        :ets.insert(
          table_for(:skill_unit_map_index),
          {{group.map_name, x, y, group.group_id}, true}
        )
      end)
    end
  end

  defp insert_timing_indexes(%Group{} = group) do
    insert_timing_index(:due, group.next_tick_at, group.group_id)
    insert_timing_index(:expiry, group.expires_at, group.group_id)
  end

  defp insert_timing_index(_kind, nil, _group_id), do: :ok

  defp insert_timing_index(kind, timestamp, group_id) do
    :ets.insert(table_for(timing_table(kind)), {{timestamp, group_id}, true})
    :ok
  end

  defp groups_due_for(kind, now_ms) do
    table = table_for(timing_table(kind))
    collect_due(table, :ets.first(table), now_ms, [])
  end

  defp insert_target_index(%Group{target_type: nil}), do: :ok
  defp insert_target_index(%Group{target_id: nil}), do: :ok

  defp insert_target_index(%Group{} = group) do
    :ets.insert(
      table_for(:skill_unit_target_index),
      {{group.target_type, group.target_id}, group.group_id}
    )

    :ok
  end

  defp delete_indexes(%Group{} = group) do
    Enum.each(group.cells, fn {x, y} ->
      :ets.delete_object(
        table_for(:skill_unit_coordinate_index),
        {{group.map_name, x, y}, group.group_id}
      )
    end)

    Enum.each(group.cells, fn {x, y} ->
      :ets.delete(table_for(:skill_unit_map_index), {group.map_name, x, y, group.group_id})
    end)

    delete_timing_index(:due, group.next_tick_at, group.group_id)
    delete_timing_index(:expiry, group.expires_at, group.group_id)

    :ets.delete_object(
      table_for(:skill_unit_caster_index),
      {{group.caster_type, group.caster_id}, group.group_id}
    )

    delete_target_index(group)
    :ok
  end

  defp delete_timing_index(_kind, nil, _group_id), do: :ok

  defp delete_timing_index(kind, timestamp, group_id) do
    :ets.delete(table_for(timing_table(kind)), {timestamp, group_id})
    :ok
  end

  defp delete_target_index(%Group{target_type: nil}), do: :ok
  defp delete_target_index(%Group{target_id: nil}), do: :ok

  defp delete_target_index(%Group{} = group) do
    :ets.delete_object(
      table_for(:skill_unit_target_index),
      {{group.target_type, group.target_id}, group.group_id}
    )

    :ok
  end

  defp indexed_groups(table, unit_type, unit_id) do
    table
    |> table_for()
    |> :ets.lookup({unit_type, unit_id})
    |> Enum.map(fn {_identity, group_id} -> group_id end)
    |> indexed_groups()
  end

  defp indexed_groups(group_ids) do
    group_ids
    |> Enum.map(&get/1)
    |> Enum.reject(&is_nil/1)
  end

  defp collect_due(_table, :"$end_of_table", _now_ms, group_ids) do
    group_ids |> Enum.reverse() |> indexed_groups()
  end

  defp collect_due(table, {timestamp, group_id} = key, now_ms, group_ids)
       when timestamp <= now_ms do
    collect_due(table, :ets.next(table, key), now_ms, [group_id | group_ids])
  end

  defp collect_due(_table, _key, _now_ms, group_ids) do
    group_ids |> Enum.reverse() |> indexed_groups()
  end

  defp timing_table(:due), do: :skill_unit_due_index
  defp timing_table(:expiry), do: :skill_unit_expiry_index

  defp store_cell(%Cell{} = cell) do
    :ets.insert(table_for(:skill_unit_cells), {cell.cell_id, cell})

    :ets.insert(table_for(:skill_unit_group_cells_index), {cell.group_id, cell.cell_id})

    :ok
  end

  defp delete_cell_indexes(%Cell{} = cell) do
    :ets.delete_object(table_for(:skill_unit_group_cells_index), {cell.group_id, cell.cell_id})

    :ok
  end

  defp indexed_group_ids_in_range(map_name, x, y, range) do
    :ets.select(table_for(:skill_unit_map_index), [
      {{{map_name, :"$1", :"$2", :"$3"}, :_},
       [
         {:>=, :"$1", x - range},
         {:"=<", :"$1", x + range},
         {:>=, :"$2", y - range},
         {:"=<", :"$2", y + range}
       ], [:"$3"]}
    ])
    |> Enum.uniq()
  end

  defp clear_observer_groups(observer_id) do
    table_for(:skill_unit_observer_groups)
    |> :ets.match({{observer_id, :"$1"}, :_})
    |> Enum.each(fn [group_id] -> remove_observer_group(observer_id, group_id) end)
  end
end
