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
  cart side by this module's `apply_change/4`. Removing from a container never
  needs a weight check; only the destination is validated, against the cart's
  flat 8000 cap or the player's STR-derived inventory cap respectively.
  """

  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Cart.Persistence
  alias Aesir.ZoneServer.Unit.Cart.Weight, as: CartWeight
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight, as: InventoryWeight
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @max_slots 100

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

  Validates the cart's flat weight cap for the moved item before any write and
  rejects with `{:error, :overweight}` when it would be exceeded; the 100-slot
  cap is enforced while adding. The item's identify/refine/attribute/cards/random
  options/bound/favorite are preserved so it arrives unchanged (a carded or
  refined item never merges with a plain stack). The inventory removal and the
  cart add commit in one transaction.
  """
  @spec move_to_cart(integer(), inventory(), cart(), non_neg_integer(), pos_integer()) ::
          move_result()
  def move_to_cart(char_id, inventory, cart, index, amount)
      when is_integer(amount) and amount > 0 do
    with {:ok, item} <- fetch(inventory, index, amount),
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(item.nameid),
         :ok <- ensure_cart_capacity(cart, item_def.weight * amount),
         {:ok, new_inventory, inv_change} <- Inventory.remove(inventory, index, amount),
         {:ok, new_cart, cart_change} <- add_preserving(cart, item_def, amount, item),
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

  Items re-entering the inventory count toward the player's STR-derived weight,
  so the inventory cap is validated first and `{:error, :overweight}` is returned
  when it would be exceeded. Attributes are preserved exactly as in
  `move_to_cart/5`. The cart removal and the inventory add commit in one
  transaction.
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
         :ok <- ensure_inventory_capacity(inventory, stats, item_def.weight * amount),
         {:ok, new_cart, cart_change} <- Cart.remove(cart, index, amount),
         {:ok, new_inventory, inv_change} <- add_preserving(inventory, item_def, amount, item),
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

  @spec ensure_cart_capacity(cart(), integer()) :: :ok | {:error, :overweight}
  defp ensure_cart_capacity(cart, added_weight) do
    if CartWeight.would_exceed?(cart, added_weight), do: {:error, :overweight}, else: :ok
  end

  @spec ensure_inventory_capacity(inventory(), Stats.t(), integer()) ::
          :ok | {:error, :overweight}
  defp ensure_inventory_capacity(inventory, stats, added_weight) do
    if InventoryWeight.would_exceed?(inventory, stats, added_weight),
      do: {:error, :overweight},
      else: :ok
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

  @spec item_opts(InventoryItem.t()) :: map()
  defp item_opts(%InventoryItem{} = item) do
    %{
      identify: item.identify,
      refine: item.refine,
      attribute: item.attribute,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      random_options: item.random_options,
      bound: item.bound,
      favorite: item.favorite
    }
  end

  # Adds the moved item to `destination`, preserving its attributes. A plain item
  # (no refine/cards/random options/attribute/bound) may stack via the shared
  # core; anything distinguishing always takes its own fresh slot so a refined or
  # carded item never merges onto a plain stack and loses its attributes (the
  # core's stack test keys on the existing slot only and ignores refine).
  @spec add_preserving(map(), ItemDefinition.t(), pos_integer(), InventoryItem.t()) ::
          Inventory.op_result()
  defp add_preserving(destination, %ItemDefinition{} = item_def, amount, %InventoryItem{} = item) do
    if plain?(item) do
      Inventory.add(destination, item_def, amount, item_opts(item))
    else
      add_to_new_slot(destination, item_def, amount, item)
    end
  end

  @spec plain?(InventoryItem.t()) :: boolean()
  defp plain?(%InventoryItem{} = item) do
    zero_fields = [
      item.refine,
      item.attribute,
      item.bound,
      item.card0,
      item.card1,
      item.card2,
      item.card3
    ]

    item.identify == 1 and item.favorite == 0 and
      map_size(item.random_options) == 0 and Enum.all?(zero_fields, &(&1 == 0))
  end

  @spec add_to_new_slot(map(), ItemDefinition.t(), pos_integer(), InventoryItem.t()) ::
          Inventory.op_result()
  defp add_to_new_slot(
         destination,
         %ItemDefinition{} = item_def,
         amount,
         %InventoryItem{} = source
       ) do
    if map_size(destination) >= @max_slots do
      {:error, :inventory_full}
    else
      index = PlayerState.lowest_free_index(destination)
      item = build_item(item_def, amount, source)
      {:ok, PlayerState.put_item(destination, index, item), {:added, index, item}}
    end
  end

  @spec build_item(ItemDefinition.t(), pos_integer(), InventoryItem.t()) :: InventoryItem.t()
  defp build_item(%ItemDefinition{} = item_def, amount, %InventoryItem{} = source) do
    %InventoryItem{
      nameid: item_def.id,
      amount: amount,
      equip: 0,
      identify: source.identify,
      refine: source.refine,
      attribute: source.attribute,
      card0: source.card0,
      card1: source.card1,
      card2: source.card2,
      card3: source.card3,
      random_options: source.random_options,
      bound: source.bound,
      favorite: source.favorite
    }
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

  defp persist(char_id, old_cart, new_cart, {:split, [{topped_index, amount}, {new_index, _}]}) do
    inserted = PlayerState.get_by_index(new_cart, new_index)

    with {:ok, cart} <- update_at(old_cart, new_cart, topped_index, %{amount: amount}),
         {:ok, row} <- Persistence.insert_item(char_id, item_attrs(inserted)) do
      {:ok, PlayerState.put_item(cart, new_index, %{inserted | id: row.id, char_id: row.char_id})}
    end
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
      random_options: item.random_options,
      bound: item.bound,
      favorite: item.favorite
    }
  end
end
