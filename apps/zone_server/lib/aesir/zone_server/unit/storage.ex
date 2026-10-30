defmodule Aesir.ZoneServer.Unit.Storage do
  @moduledoc """
  Pure domain core for an account's Kafra storage container.

  Storage is account-scoped rather than character-scoped, but the item logic
  is identical to inventory and cart: operations reuse the container-agnostic
  core in `Aesir.ZoneServer.Unit.ItemContainer` (which operates purely on a
  `%{index => InventoryItem.t()}` map, enforcing the same stacking rules with
  a 600-slot cap), and the load path delegates to
  `Aesir.ZoneServer.Unit.Storage.Persistence`.

  There is no database access or socket side effect here beyond the
  persistence delegate. What may be stored is decided by the storage add
  recipe (`add_item/4`).
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.StorageItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Storage.Persistence

  @max_storage 600

  @typedoc "Storage keyed by stable session index, structurally identical to an inventory map."
  @type t :: %{non_neg_integer() => InventoryItem.t()}

  @doc """
  Returns the storage slot capacity (600, `MAX_STORAGE`).
  """
  @spec capacity() :: pos_integer()
  def capacity, do: @max_storage

  @doc """
  Loads an account's complete storage from persistence.

  Forwards to `Aesir.ZoneServer.Unit.Storage.Persistence`; kept here so the
  load path used by the storage orchestrator has a stable entry point,
  mirroring `Cart.load_cart/1`.
  """
  @spec load_storage(integer()) :: [StorageItem.t()]
  defdelegate load_storage(account_id), to: Persistence

  @doc """
  Removes `amount` from the storage item at `index`, reusing the shared container core.
  """
  @spec remove(t(), non_neg_integer(), pos_integer()) :: ItemContainer.op_result()
  defdelegate remove(storage, index, amount), to: ItemContainer

  @doc """
  Total quantity of item `nameid` held across all storage slots, regardless of metadata.
  """
  @spec held_amount(t(), integer()) :: non_neg_integer()
  defdelegate held_amount(storage, nameid), to: ItemContainer

  @doc """
  Lowest index holding a positive amount of item `nameid`, regardless of metadata,
  or `nil` when absent.
  """
  @spec stackable_index(t(), integer()) :: non_neg_integer() | nil
  defdelegate stackable_index(storage, nameid), to: ItemContainer

  @doc """
  Adds `amount` copies of `item` with the storage recipe
  (`ItemContainer.put/6`).

  Refusals are `:invalid`, `:storage_full` (the stack limit), `:restricted`
  (the item or a slotted card may not be stored), `:bound` (bound past the
  account) and `:storage_full` (a full stack or no free slot), in that order.
  Rental items are storable and keep their expiry.
  """
  @spec add_item(t(), ItemDefinition.t(), InventoryItem.t(), integer()) ::
          ItemContainer.op_result()
  def add_item(storage, %ItemDefinition{} = item_def, %InventoryItem{} = item, amount) do
    room = %{capacity: @max_storage, weight: :infinity}
    ItemContainer.put(storage, :storage, item_def, item, amount, room)
  end
end
