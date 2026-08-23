defmodule Aesir.ZoneServer.Unit.Player.Handlers.StorageOps do
  @moduledoc """
  Write-through orchestration between the pure storage core and persistence, and
  the atomic bridge that moves items between the inventory and account storage.

  This is the storage analogue of
  `Aesir.ZoneServer.Unit.Player.Handlers.CartOps`. The pure cores
  (`Aesir.ZoneServer.Unit.Storage`/`Aesir.ZoneServer.Unit.Inventory`) compute the
  new container maps plus change descriptors without touching the database; this
  module commits those changes with **persist-first** semantics.

  ## In-memory representation

  The storage map carries `%InventoryItem{}` structs (same shape as the
  inventory map, so the pure `Inventory` core and `ItemContainer` can be reused
  verbatim), but the rows live in the `storage` table behind
  `Storage.Persistence`, whose model is `%StorageItem{}`, keyed by `account_id`
  rather than `char_id`. Each in-memory storage item's `id` is its `storage` row
  id; inserts reflect the new id back into the map and updates/deletes rebuild
  the loaded `%StorageItem{}` to target the right row.

  ## Atomic moves

  A deposit or withdraw touches two tables. Both sides are committed inside one
  `Storage.Persistence.transaction/1` (a single `Repo.transact/1`), so a failure
  on either side rolls back both: the inventory side is committed by reusing
  `InventoryOps.apply_change/4` (which nests within the same transaction) and
  the storage side by this module's `persist/4`. Deposits reject an equipped or
  unstorable (guild/party/character-bound) item before any write; withdraws
  validate the player's STR-derived inventory weight cap before any write.

  The moved item's full attribute set (identify/refine/attribute/cards/random
  options/craft/bound/`unique_id`/`enchant_grade`/`expire_time`) is preserved across
  the move via `Aesir.ZoneServer.Unit.ItemContainer.add_preserving/5`, the
  shared transfer-fidelity add: a plain item may stack, anything distinguishing
  always takes a fresh slot.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight, as: InventoryWeight
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Storage
  alias Aesir.ZoneServer.Unit.Storage.Persistence

  @type inventory :: Inventory.t()
  @type storage :: Storage.t()
  @type change :: Inventory.change()

  @typedoc "Both staged container maps plus the per-side change descriptors."
  @type transfer_result ::
          {:ok, inventory(), storage(), change(), change()} | {:error, term()}

  @doc """
  Moves `amount` of the inventory item at `index` into account storage, atomically.

  Rejects with `{:error, :item_equipped}` when the item is worn (`equip` or
  `equip_switch` non-zero) and `{:error, :not_storable}` when its bind type is
  guild/party/character-bound, both before any write. The 600-slot cap is
  enforced while adding; a full storage is reported as `{:error, :storage_full}`.
  The item's full attribute set is preserved so it arrives unchanged. The
  inventory removal and the storage add commit in one transaction.
  """
  @spec deposit(integer(), integer(), inventory(), storage(), non_neg_integer(), pos_integer()) ::
          transfer_result()
  def deposit(account_id, char_id, inventory, storage, index, amount)
      when is_integer(amount) and amount > 0 do
    with {:ok, item} <- fetch(inventory, index, amount),
         :ok <- ensure_not_equipped(item),
         :ok <- ensure_storable(item),
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(item.nameid),
         {:ok, new_inventory, inv_change} <- Inventory.remove(inventory, index, amount),
         {:ok, new_storage, storage_change} <- add_to_storage(storage, item_def, amount, item),
         {:ok, persisted_inventory, persisted_storage} <-
           transact(
             account_id,
             char_id,
             inventory,
             new_inventory,
             inv_change,
             storage,
             new_storage,
             storage_change
           ) do
      {:ok, persisted_inventory, persisted_storage, inv_change, storage_change}
    end
  end

  @doc """
  Moves `amount` of the storage item at `index` back into the inventory, atomically.

  Items re-entering the inventory count toward the player's STR-derived weight,
  so the inventory cap is validated first and `{:error, :overweight}` is
  returned when it would be exceeded. Attributes are preserved exactly as in
  `deposit/6`. The storage removal and the inventory add commit in one
  transaction.
  """
  @spec withdraw(
          integer(),
          integer(),
          inventory(),
          storage(),
          Stats.t(),
          non_neg_integer(),
          pos_integer()
        ) :: transfer_result()
  def withdraw(account_id, char_id, inventory, storage, %Stats{} = stats, index, amount)
      when is_integer(amount) and amount > 0 do
    with {:ok, item} <- fetch(storage, index, amount),
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(item.nameid),
         :ok <- ensure_inventory_capacity(inventory, stats, item_def.weight * amount),
         {:ok, new_storage, storage_change} <- Storage.remove(storage, index, amount),
         {:ok, new_inventory, inv_change} <-
           ItemContainer.add_preserving(inventory, item_def, amount, Inventory.capacity(), item),
         {:ok, persisted_inventory, persisted_storage} <-
           transact(
             account_id,
             char_id,
             inventory,
             new_inventory,
             inv_change,
             storage,
             new_storage,
             storage_change
           ) do
      {:ok, persisted_inventory, persisted_storage, inv_change, storage_change}
    end
  end

  @spec transact(
          integer(),
          integer(),
          inventory(),
          inventory(),
          change(),
          storage(),
          storage(),
          change()
        ) :: {:ok, inventory(), storage()} | {:error, term()}
  defp transact(
         account_id,
         char_id,
         old_inventory,
         new_inventory,
         inv_change,
         old_storage,
         new_storage,
         storage_change
       ) do
    result =
      Persistence.transaction(fn ->
        with {:ok, persisted_inventory} <-
               InventoryOps.apply_change(char_id, old_inventory, new_inventory, inv_change),
             {:ok, persisted_storage} <-
               persist(account_id, old_storage, new_storage, storage_change) do
          {:ok, {persisted_inventory, persisted_storage}}
        end
      end)

    case result do
      {:ok, {persisted_inventory, persisted_storage}} ->
        {:ok, persisted_inventory, persisted_storage}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec add_to_storage(storage(), ItemDefinition.t(), pos_integer(), InventoryItem.t()) ::
          ItemContainer.op_result()
  defp add_to_storage(storage, %ItemDefinition{} = item_def, amount, %InventoryItem{} = item) do
    case ItemContainer.add_preserving(storage, item_def, amount, Storage.capacity(), item) do
      {:error, :inventory_full} -> {:error, :storage_full}
      result -> result
    end
  end

  @spec ensure_not_equipped(InventoryItem.t()) :: :ok | {:error, :item_equipped}
  defp ensure_not_equipped(%InventoryItem{equip: 0, equip_switch: 0}), do: :ok
  defp ensure_not_equipped(%InventoryItem{}), do: {:error, :item_equipped}

  @spec ensure_storable(InventoryItem.t()) :: :ok | {:error, :not_storable}
  defp ensure_storable(%InventoryItem{} = item) do
    if Storage.storable?(item), do: :ok, else: {:error, :not_storable}
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

  @spec persist(integer(), storage(), storage(), change()) :: {:ok, storage()} | {:error, term()}
  defp persist(account_id, _old_storage, new_storage, {:added, index, item}) do
    with {:ok, row} <- Persistence.insert_item(account_id, item_attrs(item)) do
      {:ok, PlayerState.put_item(new_storage, index, %{item | id: row.id})}
    end
  end

  defp persist(account_id, old_storage, new_storage, {:stacked, index, amount}) do
    update_at(account_id, old_storage, new_storage, index, %{amount: amount})
  end

  defp persist(
         account_id,
         old_storage,
         new_storage,
         {:split, [{topped_index, amount}, {new_index, _}]}
       ) do
    inserted = PlayerState.get_by_index(new_storage, new_index)

    with {:ok, storage} <-
           update_at(account_id, old_storage, new_storage, topped_index, %{amount: amount}),
         {:ok, row} <- Persistence.insert_item(account_id, item_attrs(inserted)) do
      {:ok, PlayerState.put_item(storage, new_index, %{inserted | id: row.id})}
    end
  end

  defp persist(account_id, old_storage, new_storage, {:removed, index}) do
    row = Persistence.to_storage_row(PlayerState.get_by_index(old_storage, index), account_id)

    with {:ok, _deleted} <- Persistence.delete_item(row) do
      {:ok, new_storage}
    end
  end

  defp persist(account_id, old_storage, new_storage, {:reduced, index, left}) do
    update_at(account_id, old_storage, new_storage, index, %{amount: left})
  end

  # Updates the storage row at `index` using the pre-change item rebuilt as a
  # loaded `%StorageItem{}` so the changeset targets the existing row; the new
  # storage map already carries the advanced amount and the same `id`, so it is
  # returned as-is.
  @spec update_at(integer(), storage(), storage(), non_neg_integer(), map()) ::
          {:ok, storage()} | {:error, term()}
  defp update_at(account_id, old_storage, new_storage, index, attrs) do
    row = Persistence.to_storage_row(PlayerState.get_by_index(old_storage, index), account_id)

    with {:ok, _updated} <- Persistence.update_item(row, attrs) do
      {:ok, new_storage}
    end
  end

  @spec item_attrs(InventoryItem.t()) :: map()
  defp item_attrs(%InventoryItem{} = item) do
    %{
      nameid: item.nameid,
      amount: item.amount,
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
      unique_id: item.unique_id,
      enchant_grade: item.enchant_grade,
      expire_time: item.expire_time
    }
  end
end
