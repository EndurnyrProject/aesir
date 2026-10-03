defmodule Aesir.ZoneServer.Unit.Cart.Persistence do
  @moduledoc """
  Ecto access for character cart rows (`CartItem` in `cart_inventory`, keyed
  by `char_id`), delegating to `ItemContainer.Persistence`. The domain core
  (`Aesir.ZoneServer.Unit.Cart`) stays pure and the orchestrator composes these
  write-through operations, optionally inside `transaction/1`, so
  inventory<->cart moves roll back atomically.
  """

  alias Aesir.Commons.Models.CartItem
  alias Aesir.ZoneServer.Unit.ItemContainer.Persistence

  @type item_result :: {:ok, CartItem.t()} | {:error, Ecto.Changeset.t()}

  @doc "Loads a character's complete cart ordered by row `id`."
  @spec load_cart(integer()) :: [CartItem.t()]
  def load_cart(char_id), do: Persistence.load(CartItem, :char_id, char_id)

  @doc "Inserts a new cart item for the given character."
  @spec insert_item(integer(), map()) :: item_result()
  def insert_item(char_id, attrs), do: Persistence.insert(CartItem, :char_id, char_id, attrs)

  @doc "Updates an existing cart item with the given attributes."
  @spec update_item(CartItem.t(), map()) :: item_result()
  def update_item(%CartItem{} = item, attrs), do: Persistence.update(item, attrs)

  @doc "Deletes a cart item."
  @spec delete_item(CartItem.t()) :: item_result()
  def delete_item(%CartItem{} = item), do: Persistence.delete(item)

  @doc "Runs `fun` inside a database transaction (see `ItemContainer.Persistence.transaction/1`)."
  @spec transaction((-> {:ok, term()} | {:error, term()})) :: {:ok, term()} | {:error, term()}
  defdelegate transaction(fun), to: Persistence
end
