defmodule Aesir.ZoneServer.Unit.Player.Handlers.CartOps do
  @moduledoc """
  Write-through orchestration between the pure cart core and persistence, and
  the atomic bridge that moves items between the inventory and the cart.

  This is the cart analogue of
  `Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps`. The pure cores
  (`Aesir.ZoneServer.Unit.Cart`/`Aesir.ZoneServer.Unit.Inventory`) compute the
  new container maps plus change descriptors without touching the database; this
  module commits those changes with **persist-first** semantics.

  ## In-memory representation

  The cart map carries `%InventoryItem{}` structs (same shape as the inventory
  map, so the pure `Inventory` core and `Cart.Weight` can be reused verbatim),
  but the rows live in the `cart_inventory` table behind `Cart.Persistence`,
  whose model is `%CartItem{}`. Each in-memory cart item's `id` is its
  `cart_inventory` row id; inserts reflect the new id back into the map and
  updates/deletes rebuild the loaded `%CartItem{}` to target the right row.

  ## Atomic moves

  A move touches two tables. Both sides are committed inside one
  `Cart.Persistence.transaction/1` (a single `Repo.transact/1`), so a failure on
  either side rolls back both: the inventory side is committed by reusing
  `InventoryOps.apply_change/4` (which nests within the same transaction) and the
  cart side by this module's `apply_change/4`. Only the destination is
  checked: an item enters the cart with the cart add recipe (`Cart.add_item/4`,
  the flat weight cap included) and the inventory with the inventory recipe
  (`Inventory.add_item/5`, the player's free weight included); either refusal
  returns before any write.
  """

  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Cart.Persistence
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @type cart :: Cart.t()
  @type inventory :: Inventory.t()
  @type change :: Inventory.change()

  @typedoc "Both staged container maps plus the per-side change descriptors."
  @type move_result ::
          {:ok, inventory(), cart(), change(), change()} | {:error, term()}

  @doc """
  Persists a cart `change` and returns the advanced cart map.

  Mirrors `InventoryOps.apply_change/4` against the `cart_inventory` table.
  `old_cart` is the pre-change map (needed to locate rows to update/delete);
  `new_cart` is the map the pure core produced. The whole change runs inside a
  single transaction; inserted items carry their real DB `id` on success.
  """
  @spec apply_change(integer(), cart(), cart(), change()) :: {:ok, cart()} | {:error, term()}
  def apply_change(char_id, old_cart, new_cart, change) do
    Persistence.transaction(fn -> persist(char_id, old_cart, new_cart, change) end)
  end

  @doc """
  Moves `amount` of the inventory item at `index` into the cart, atomically.

  The item enters with the cart recipe (`Cart.add_item/4`); a refusal returns
  before any write. The inventory removal and the cart add commit in one
  transaction.
  """
  @spec move_to_cart(integer(), inventory(), cart(), non_neg_integer(), pos_integer()) ::
          move_result()
  def move_to_cart(char_id, inventory, cart, index, amount)
      when is_integer(amount) and amount > 0 do
    with {:ok, item} <- fetch(inventory, index, amount),
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(item.nameid),
         {:ok, new_cart, cart_change} <- Cart.add_item(cart, item_def, item, amount),
         {:ok, new_inventory, inv_change} <- Inventory.remove(inventory, index, amount),
         {:ok, persisted_inventory, persisted_cart} <-
           transact_move(
             char_id,
             inventory,
             new_inventory,
             inv_change,
             cart,
             new_cart,
             cart_change
           ) do
      {:ok, persisted_inventory, persisted_cart, inv_change, cart_change}
    end
  end

  @doc """
  Moves `amount` of the cart item at `index` back into the inventory, atomically.

  The item enters with the inventory recipe (`Inventory.add_item/5`), weighed
  against the player's free weight; a refusal returns before any write. The
  cart removal and the inventory add commit in one transaction.
  """
  @spec move_to_inventory(
          integer(),
          inventory(),
          cart(),
          Stats.t(),
          non_neg_integer(),
          pos_integer()
        ) ::
          move_result()
  def move_to_inventory(char_id, inventory, cart, %Stats{} = stats, index, amount)
      when is_integer(amount) and amount > 0 do
    with {:ok, item} <- fetch(cart, index, amount),
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(item.nameid),
         {:ok, new_inventory, inv_change} <-
           Inventory.add_item(
             inventory,
             item_def,
             item,
             amount,
             Inventory.weight_room(inventory, stats)
           ),
         {:ok, new_cart, cart_change} <- Cart.remove(cart, index, amount),
         {:ok, persisted_inventory, persisted_cart} <-
           transact_move(
             char_id,
             inventory,
             new_inventory,
             inv_change,
             cart,
             new_cart,
             cart_change
           ) do
      {:ok, persisted_inventory, persisted_cart, inv_change, cart_change}
    end
  end

  @spec transact_move(integer(), inventory(), inventory(), change(), cart(), cart(), change()) ::
          {:ok, inventory(), cart()} | {:error, term()}
  defp transact_move(
         char_id,
         old_inventory,
         new_inventory,
         inv_change,
         old_cart,
         new_cart,
         cart_change
       ) do
    result =
      Persistence.transaction(fn ->
        with {:ok, persisted_inventory} <-
               InventoryOps.apply_change(char_id, old_inventory, new_inventory, inv_change),
             {:ok, persisted_cart} <- persist(char_id, old_cart, new_cart, cart_change) do
          {:ok, {persisted_inventory, persisted_cart}}
        end
      end)

    case result do
      {:ok, {persisted_inventory, persisted_cart}} -> {:ok, persisted_inventory, persisted_cart}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch(map(), non_neg_integer(), pos_integer()) ::
          {:ok, InventoryItem.t()} | {:error, atom()}
  defp fetch(container, index, amount) do
    case Map.get(container, index) do
      nil -> {:error, :not_found}
      %InventoryItem{amount: held} when held < amount -> {:error, :insufficient_amount}
      %InventoryItem{} = item -> {:ok, item}
    end
  end

  @spec persist(integer(), cart(), cart(), change()) :: {:ok, cart()} | {:error, term()}
  defp persist(char_id, _old_cart, new_cart, {:added, index, item}) do
    with {:ok, row} <- Persistence.insert_item(char_id, item_attrs(item)) do
      {:ok, PlayerState.put_item(new_cart, index, %{item | id: row.id, char_id: row.char_id})}
    end
  end

  defp persist(_char_id, old_cart, new_cart, {:stacked, index, amount}) do
    update_at(old_cart, new_cart, index, %{amount: amount})
  end

  defp persist(_char_id, old_cart, new_cart, {:removed, index}) do
    row = to_cart_row(PlayerState.get_by_index(old_cart, index))

    with {:ok, _deleted} <- Persistence.delete_item(row) do
      {:ok, new_cart}
    end
  end

  defp persist(_char_id, old_cart, new_cart, {:reduced, index, left}) do
    update_at(old_cart, new_cart, index, %{amount: left})
  end

  # Updates the cart row at `index` using the pre-change item rebuilt as a loaded
  # `%CartItem{}` so the changeset targets the existing row; the new cart map
  # already carries the advanced amount and the same `id`, so it is returned as-is.
  @spec update_at(cart(), cart(), non_neg_integer(), map()) :: {:ok, cart()} | {:error, term()}
  defp update_at(old_cart, new_cart, index, attrs) do
    row = to_cart_row(PlayerState.get_by_index(old_cart, index))

    with {:ok, _updated} <- Persistence.update_item(row, attrs) do
      {:ok, new_cart}
    end
  end

  @spec to_cart_row(InventoryItem.t()) :: CartItem.t()
  defp to_cart_row(%InventoryItem{} = item) do
    attrs =
      item
      |> item_attrs()
      |> Map.put(:id, item.id)
      |> Map.put(:char_id, item.char_id)

    Ecto.put_meta(struct(CartItem, attrs), state: :loaded)
  end

  @spec item_attrs(InventoryItem.t()) :: map()
  defp item_attrs(%InventoryItem{} = item) do
    %{
      nameid: item.nameid,
      amount: item.amount,
      equip: item.equip,
      identify: item.identify,
      refine: item.refine,
      attribute: item.attribute,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      craft: item.craft,
      random_options: item.random_options,
      bound: item.bound,
      favorite: item.favorite,
      unique_id: item.unique_id,
      enchant_grade: item.enchant_grade,
      expire_time: item.expire_time
    }
  end
end
