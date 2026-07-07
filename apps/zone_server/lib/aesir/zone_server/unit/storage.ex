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
  persistence delegate; the `storable?/1` bound-type policy check is the only
  storage-specific rule.
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
  Adds `amount` of `item_def` to `storage`, reusing the shared container core.

  Stacks, splits, and the 600-slot cap behave exactly as `Inventory.add/4`.
  """
  @spec add(t(), ItemDefinition.t(), pos_integer(), map()) :: ItemContainer.op_result()
  def add(storage, %ItemDefinition{} = item_def, amount, opts \\ %{}) do
    ItemContainer.add(storage, item_def, amount, @max_storage, opts)
  end

  @doc """
  Removes `amount` from the storage item at `index`, reusing the shared container core.
  """
  @spec remove(t(), non_neg_integer(), pos_integer()) :: ItemContainer.op_result()
  defdelegate remove(storage, index, amount), to: ItemContainer

  @doc """
  Total quantity of item `nameid` held across all stackable storage slots.
  """
  @spec held_amount(t(), integer()) :: non_neg_integer()
  defdelegate held_amount(storage, nameid), to: ItemContainer

  @doc """
  Index of a stackable storage slot holding item `nameid`, or `nil` when none.
  """
  @spec stackable_index(t(), integer()) :: non_neg_integer() | nil
  defdelegate stackable_index(storage, nameid), to: ItemContainer

  @doc """
  Checks whether an item may enter personal storage based on its `bound` value.

  Unbound (`0`) and account-bound (`1`) items are storable; guild-bound (`2`),
  party-bound (`3`), and character-bound (`4`) items are rejected.
  """
  @spec storable?(InventoryItem.t()) :: boolean()
  def storable?(%InventoryItem{bound: bound}), do: bound in [0, 1]
end
