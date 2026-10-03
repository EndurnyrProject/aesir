defmodule Aesir.ZoneServer.Unit.Inventory.Persistence do
  @moduledoc """
  Ecto access for character inventory rows (`InventoryItem`, keyed by
  `char_id`), delegating to `ItemContainer.Persistence`. The domain core
  (`Aesir.ZoneServer.Unit.Inventory`) stays pure and the orchestrator composes
  these write-through operations, optionally inside `transaction/1`, so
  multi-row changes (stack splits, equip-with-conflict) roll back atomically.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.ItemContainer.Persistence

  @type item_result :: {:ok, InventoryItem.t()} | {:error, Ecto.Changeset.t()}

  @doc "Loads a character's complete inventory ordered by row `id`."
  @spec load_inventory(integer()) :: [InventoryItem.t()]
  def load_inventory(char_id), do: Persistence.load(InventoryItem, :char_id, char_id)

  @doc "Inserts a new inventory item for the given character."
  @spec insert_item(integer(), map()) :: item_result()
  def insert_item(char_id, attrs), do: Persistence.insert(InventoryItem, :char_id, char_id, attrs)

  @doc "Updates an existing inventory item with the given attributes."
  @spec update_item(InventoryItem.t(), map()) :: item_result()
  def update_item(%InventoryItem{} = item, attrs), do: Persistence.update(item, attrs)

  @doc "Deletes an inventory item."
  @spec delete_item(InventoryItem.t()) :: item_result()
  def delete_item(%InventoryItem{} = item), do: Persistence.delete(item)

  @doc "Runs `fun` inside a database transaction (see `ItemContainer.Persistence.transaction/1`)."
  @spec transaction((-> {:ok, term()} | {:error, term()})) :: {:ok, term()} | {:error, term()}
  defdelegate transaction(fun), to: Persistence
end
