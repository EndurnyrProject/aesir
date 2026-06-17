defmodule Aesir.ZoneServer.Mmo.SkillUnit.Storage do
  @moduledoc """
  ETS-based storage for ground skill-unit groups.

  Mirrors `Aesir.ZoneServer.Mmo.StatusStorage`: a single `:set` table keyed by
  `group_id` holding one `Group` per cast, with `:ets.select` match-specs that
  return only the groups due for a tick (`next_tick_at <= now`) or ready to expire
  (`expires_at <= now`). This keeps the central tick loop processing only the work
  that is actually due.
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.SkillUnit.Group

  @doc """
  Inserts (or replaces) a group, keyed by its `group_id`.
  """
  @spec insert(Group.t()) :: :ok
  def insert(%Group{group_id: group_id} = group) do
    :ets.insert(table_for(:skill_units), {group_id, group})
    :ok
  end

  @doc """
  Replaces an existing group. Alias of `insert/1` for call-site clarity.
  """
  @spec update(Group.t()) :: :ok
  def update(%Group{} = group), do: insert(group)

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
  Returns groups whose `next_tick_at <= now_ms` (due for an interval tick).
  """
  @spec get_due_groups(integer()) :: [Group.t()]
  def get_due_groups(now_ms) do
    match_spec = [
      {
        {:_, :"$1"},
        [{:"=<", {:map_get, :next_tick_at, :"$1"}, now_ms}],
        [:"$1"]
      }
    ]

    :ets.select(table_for(:skill_units), match_spec)
  end

  @doc """
  Returns groups whose `expires_at <= now_ms` (ready to be reaped).
  """
  @spec get_expired_groups(integer()) :: [Group.t()]
  def get_expired_groups(now_ms) do
    match_spec = [
      {
        {:_, :"$1"},
        [{:"=<", {:map_get, :expires_at, :"$1"}, now_ms}],
        [:"$1"]
      }
    ]

    :ets.select(table_for(:skill_units), match_spec)
  end
end
