defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Storage do
  @moduledoc """
  ETS-based storage for ground skill-unit groups.

  One `:set` table owns the authoritative `Group` rows. Synchronized ETS indexes
  serve exact coordinate, caster, and target lookups plus due/expiry queries,
  keeping the central tick loop and movement hooks off full group scans.
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

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

  @doc """
  Deletes a group by `group_id`.
  """
  @spec delete(non_neg_integer()) :: :ok
  def delete(group_id) do
    case get(group_id) do
      nil -> :ok
      group -> delete_indexes(group)
    end

    :ets.delete(table_for(:skill_units), group_id)
    :ok
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

  @doc "Returns every group owned by the given caster."
  @spec get_groups_by_caster(atom(), integer()) :: [Group.t()]
  def get_groups_by_caster(caster_type, caster_id) do
    indexed_groups(:skill_unit_caster_index, caster_type, caster_id)
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
end
