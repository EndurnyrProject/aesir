defmodule Aesir.ZoneServer.Unit.Cart.Persistence do
  @moduledoc """
  Low-level Ecto access for a character's cart.

  The cart analogue of `Aesir.ZoneServer.Unit.Inventory.Persistence`: it owns
  every database read and write for cart items against the `cart_inventory`
  table. The domain core (`Aesir.ZoneServer.Unit.Cart`) stays pure and the
  orchestrator composes these write-through operations, optionally inside
  `transaction/1`, so inventory<->cart moves roll back atomically.
  """

  import Ecto.Query

  alias Aesir.Commons.Models.CartItem
  alias Aesir.Repo

  @type item_result :: {:ok, CartItem.t()} | {:error, Ecto.Changeset.t()}
  @type load_result :: {:ok, [CartItem.t()]} | {:error, term()}

  @doc """
  Loads a character's complete cart ordered by row `id`.
  """
  @spec load_cart(integer()) :: load_result()
  def load_cart(char_id) do
    items =
      CartItem
      |> where([i], i.char_id == ^char_id)
      |> order_by([i], i.id)
      |> Repo.all()

    {:ok, items}
  end

  @doc """
  Inserts a new cart item for the given character.
  """
  @spec insert_item(integer(), map()) :: item_result()
  def insert_item(char_id, attrs) do
    %CartItem{}
    |> CartItem.changeset(Map.put(attrs, :char_id, char_id))
    |> Repo.insert()
  end

  @doc """
  Updates an existing cart item with the given attributes.
  """
  @spec update_item(CartItem.t(), map()) :: item_result()
  def update_item(%CartItem{} = item, attrs) do
    item
    |> CartItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cart item.
  """
  @spec delete_item(CartItem.t()) :: item_result()
  def delete_item(%CartItem{} = item) do
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
