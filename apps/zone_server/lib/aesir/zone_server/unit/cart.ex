defmodule Aesir.ZoneServer.Unit.Cart do
  @moduledoc """
  Pure domain core for a character's pushcart container.

  The cart is "an inventory map with a different weight cap and a different DB
  table", so this module is intentionally thin: storage operations reuse the
  container-agnostic core in `Aesir.ZoneServer.Unit.ItemContainer` (which
  operates purely on a `%{index => InventoryItem.t()}` map, enforcing the same
  100-slot cap and stacking rules), and the load path delegates to
  `Aesir.ZoneServer.Unit.Cart.Persistence`.

  There is no database access or socket side effect here beyond the persistence
  delegate; weight limits and packet emission are the orchestrator's job. The
  cart-specific 8000-weight cap lives in `Aesir.ZoneServer.Unit.Cart.Weight`.
  """

  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Unit.Cart.Persistence
  alias Aesir.ZoneServer.Unit.ItemContainer

  @max_cart 100

  @typedoc "Cart keyed by stable session index, structurally identical to an inventory map."
  @type t :: %{non_neg_integer() => InventoryItem.t()}

  @doc """
  Loads a character's complete cart from persistence.

  Forwards to `Aesir.ZoneServer.Unit.Cart.Persistence`; kept here so the load
  path used by the cart orchestrator has a stable entry point, mirroring
  `Inventory.load_inventory/1`.
  """
  @spec load_cart(integer()) :: [CartItem.t()]
  defdelegate load_cart(char_id), to: Persistence

  @doc """
  The cart's slot cap.
  """
  @spec capacity() :: pos_integer()
  def capacity, do: @max_cart

  @doc """
  Adds `amount` of `item_def` to `cart`, reusing the shared container core.

  Stacks, splits, and the 100-slot cap behave exactly as `Inventory.add/4`;
  weight is enforced by the orchestrator, not here.
  """
  @spec add(t(), ItemDefinition.t(), pos_integer(), map()) :: ItemContainer.op_result()
  def add(cart, %ItemDefinition{} = item_def, amount, opts \\ %{}) do
    ItemContainer.add(cart, item_def, amount, @max_cart, opts)
  end

  @doc """
  Removes `amount` from the cart item at `index`, reusing the shared container core.
  """
  @spec remove(t(), non_neg_integer(), pos_integer()) :: ItemContainer.op_result()
  defdelegate remove(cart, index, amount), to: ItemContainer

  @doc """
  Total quantity of item `nameid` held across all stackable cart slots.
  """
  @spec held_amount(t(), integer()) :: non_neg_integer()
  defdelegate held_amount(cart, nameid), to: ItemContainer

  @doc """
  Index of a stackable cart slot holding item `nameid`, or `nil` when none.
  """
  @spec stackable_index(t(), integer()) :: non_neg_integer() | nil
  defdelegate stackable_index(cart, nameid), to: ItemContainer
end
