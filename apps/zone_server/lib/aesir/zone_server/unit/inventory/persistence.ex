defmodule Aesir.ZoneServer.Unit.Inventory.Persistence do
  @moduledoc """
  Low-level Ecto access for character inventory.

  Owns every database read and write for inventory items. The domain core
  (`Aesir.ZoneServer.Unit.Inventory`) stays pure and the orchestrator composes
  these write-through operations, optionally inside `transaction/1`, so multi-row
  changes (stack splits, equip-with-conflict) roll back atomically.
  """

  import Ecto.Query

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Repo

  @type item_result :: {:ok, InventoryItem.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Loads a character's complete inventory ordered by row `id`.
  """
  @spec load_inventory(integer()) :: [InventoryItem.t()]
  def load_inventory(char_id) do
    InventoryItem
    |> where([i], i.char_id == ^char_id)
    |> order_by([i], i.id)
    |> Repo.all()
  end

  @doc """
  Inserts a new inventory item for the given character.
  """
  @spec insert_item(integer(), map()) :: item_result()
  def insert_item(char_id, attrs) do
    %InventoryItem{}
    |> InventoryItem.changeset(Map.put(attrs, :char_id, char_id))
    |> Repo.insert()
  end

  @doc """
  Updates an existing inventory item with the given attributes.
  """
  @spec update_item(InventoryItem.t(), map()) :: item_result()
  def update_item(%InventoryItem{} = item, attrs) do
    item
    |> InventoryItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an inventory item.
  """
  @spec delete_item(InventoryItem.t()) :: item_result()
  def delete_item(%InventoryItem{} = item) do
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
end
