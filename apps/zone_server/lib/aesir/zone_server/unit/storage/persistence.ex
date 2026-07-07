defmodule Aesir.ZoneServer.Unit.Storage.Persistence do
  @moduledoc """
  Low-level Ecto access for an account's Kafra storage.

  The storage analogue of `Aesir.ZoneServer.Unit.Cart.Persistence`: it owns
  every database read and write for storage items against the `storage`
  table, keyed by `account_id` rather than `char_id`. The domain core
  (`Aesir.ZoneServer.Unit.Storage`) stays pure and the orchestrator composes
  these write-through operations, optionally inside `transaction/1`, so
  inventory<->storage moves roll back atomically.

  Also owns the two persistence-edge mappings between the session
  `%InventoryItem{}` struct (which every in-session container, including
  storage, holds) and the storage-specific `%StorageItem{}` row: `to_session_item/1`
  and `to_storage_row/2`.
  """

  import Ecto.Query

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.StorageItem
  alias Aesir.Repo

  @type item_result :: {:ok, StorageItem.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Loads an account's complete storage ordered by row `id`.
  """
  @spec load_storage(integer()) :: [StorageItem.t()]
  def load_storage(account_id) do
    StorageItem
    |> where([i], i.account_id == ^account_id)
    |> order_by([i], i.id)
    |> Repo.all()
  end

  @doc """
  Inserts a new storage item for the given account.
  """
  @spec insert_item(integer(), map()) :: item_result()
  def insert_item(account_id, attrs) do
    %StorageItem{}
    |> StorageItem.changeset(Map.put(attrs, :account_id, account_id))
    |> Repo.insert()
  end

  @doc """
  Updates an existing storage item with the given attributes.
  """
  @spec update_item(StorageItem.t(), map()) :: item_result()
  def update_item(%StorageItem{} = item, attrs) do
    item
    |> StorageItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a storage item.
  """
  @spec delete_item(StorageItem.t()) :: item_result()
  def delete_item(%StorageItem{} = item) do
    Repo.delete(item)
  end

  @doc """
  Runs `fun` inside a database transaction, rolling back when it returns an
  `{:error, reason}` tuple and committing on `{:ok, result}`.
  """
  @spec transaction((-> {:ok, term()} | {:error, term()})) :: {:ok, term()} | {:error, term()}
  def transaction(fun) when is_function(fun, 0) do
    Repo.transact(fun)
  end

  @doc """
  Converts a loaded `%StorageItem{}` row into the session `%InventoryItem{}`
  struct every in-session container holds.

  Storage rows are never worn, so `equip` is always `0`.
  """
  @spec to_session_item(StorageItem.t()) :: InventoryItem.t()
  def to_session_item(%StorageItem{} = row) do
    %InventoryItem{
      id: row.id,
      nameid: row.nameid,
      amount: row.amount,
      equip: 0,
      identify: row.identify,
      refine: row.refine,
      attribute: row.attribute,
      card0: row.card0,
      card1: row.card1,
      card2: row.card2,
      card3: row.card3,
      random_options: row.random_options,
      expire_time: row.expire_time,
      bound: row.bound,
      unique_id: row.unique_id,
      enchant_grade: row.enchant_grade
    }
  end

  @doc """
  Converts a session `%InventoryItem{}` back into a loaded `%StorageItem{}`
  targeting the existing row, mirroring `CartOps.to_cart_row/1`.
  """
  @spec to_storage_row(InventoryItem.t(), integer()) :: StorageItem.t()
  def to_storage_row(%InventoryItem{} = item, account_id) do
    attrs = %{
      id: item.id,
      account_id: account_id,
      nameid: item.nameid,
      amount: item.amount,
      identify: item.identify,
      refine: item.refine,
      attribute: item.attribute,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      random_options: item.random_options,
      expire_time: item.expire_time,
      bound: item.bound,
      unique_id: item.unique_id,
      enchant_grade: item.enchant_grade
    }

    Ecto.put_meta(struct(StorageItem, attrs), state: :loaded)
  end
end
