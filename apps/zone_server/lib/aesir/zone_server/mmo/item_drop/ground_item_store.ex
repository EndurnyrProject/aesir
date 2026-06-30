defmodule Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore do
  @moduledoc """
  Mutable ETS store of ground items, keyed by `{map_name, ground_id}`.

  Mirrors the `Unit.SpatialIndex` pattern: many concurrent lock-free readers
  (player sessions on view-enter) and a single writer (the owning map
  `Coordinator`). Entries are stored as `{{map_name, ground_id}, GroundItem.t()}`.

  Maps are keyed by their **clean** name (no `.gat` suffix), so ground items
  land in the same cells as players/mobs in `SpatialIndex` — mismatched keying
  is a recurring footgun that makes entities invisible.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem

  @doc """
  Inserts a ground item onto `map_name`. Writer (Coordinator) only.
  """
  @spec put(String.t(), GroundItem.t()) :: :ok
  def put(map_name, %GroundItem{id: id} = item) do
    :ets.insert(table_for(:ground_items), {{map_name, id}, item})
    :ok
  end

  @doc """
  Returns the ground items on `map_name` within `range` (Manhattan distance) of
  `{x, y}`. Lock-free read.
  """
  @spec query_in_range(String.t(), integer(), integer(), non_neg_integer()) :: [GroundItem.t()]
  def query_in_range(map_name, x, y, range) do
    table_for(:ground_items)
    |> :ets.match_object({{map_name, :_}, :_})
    |> Enum.map(fn {_key, item} -> item end)
    |> Enum.filter(fn %GroundItem{x: ix, y: iy} -> abs(ix - x) + abs(iy - y) <= range end)
  end

  @doc """
  Returns the ground item `ground_id` on `map_name` without removing it, or
  `{:error, :gone}` when it is absent. Lock-free read used to locate an item the
  player clicked from out of pickup range so we can walk to it.
  """
  @spec get(String.t(), pos_integer()) :: {:ok, GroundItem.t()} | {:error, :gone}
  def get(map_name, ground_id) do
    case :ets.lookup(table_for(:ground_items), {map_name, ground_id}) do
      [{_key, item}] -> {:ok, item}
      [] -> {:error, :gone}
    end
  end

  @doc """
  Atomically removes and returns the ground item `ground_id` from `map_name`.

  Uses `:ets.take/2` so two concurrent claims resolve to exactly one `{:ok, item}`
  and one `{:error, :gone}`.
  """
  @spec claim(String.t(), pos_integer()) :: {:ok, GroundItem.t()} | {:error, :gone}
  def claim(map_name, ground_id) do
    case :ets.take(table_for(:ground_items), {map_name, ground_id}) do
      [{_key, item}] -> {:ok, item}
      [] -> {:error, :gone}
    end
  end

  @doc """
  Removes and returns the ground items on `map_name` whose `dropped_at` is older
  than `now - ttl_ms`. Writer (Coordinator) only.
  """
  @spec expire_due(String.t(), integer(), non_neg_integer()) :: [GroundItem.t()]
  def expire_due(map_name, now, ttl_ms) do
    cutoff = now - ttl_ms
    table = table_for(:ground_items)

    table
    |> :ets.match_object({{map_name, :_}, :_})
    |> Enum.filter(fn {_key, %GroundItem{dropped_at: dropped_at}} -> dropped_at < cutoff end)
    |> Enum.map(fn {key, item} ->
      :ets.delete(table, key)
      item
    end)
  end
end
