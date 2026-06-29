defmodule Aesir.ZoneServer.Unit.Cart.Weight do
  @moduledoc """
  Pure weight calculations for a player's cart.

  Mirrors `Aesir.ZoneServer.Unit.Inventory.Weight`, but the cart has its own
  independent, flat capacity: items in the cart do not count toward player
  weight and the cap is not STR-derived.

  - `current_weight/1` sums `ItemDefinition.weight × amount` over every item in
    the cart map.
  - `max_weight/0` is the flat cart cap (`80_000`).
  - `would_exceed?/2` reports whether adding `added_weight` would cross the cap.

  ## Unit

  Weights use the same unit Aesir uses everywhere: the `ItemDefinition.weight` and
  `Job.max_weight` db values (e.g. Red Potion = `70`, merchant inventory cap
  `~28_000`). The cart cap is `80_000` — `~2.85×` the inventory cap, the RO
  cart-to-inventory ratio. (An earlier `8000` was rAthena's `max_cart_weight`
  config value copied directly; rAthena multiplies it by 10 at load, so it does not
  belong in this unit.)

  Reads item definitions from `:persistent_term` via `ItemManagement`; no DB or
  socket access.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement

  @max_cart_weight 80_000

  @type cart :: %{non_neg_integer() => InventoryItem.t()}

  @doc """
  The flat maximum weight a cart can hold.
  """
  @spec max_weight() :: non_neg_integer()
  def max_weight, do: @max_cart_weight

  @doc """
  Total weight of every item in the cart.
  """
  @spec current_weight(cart()) :: non_neg_integer()
  def current_weight(cart) when is_map(cart) do
    cart
    |> Map.values()
    |> Enum.reduce(0, fn %InventoryItem{nameid: nameid, amount: amount}, acc ->
      acc + item_weight(nameid) * amount
    end)
  end

  @doc """
  Whether adding `added_weight` would push the cart past its flat cap.

  Reaching the cap exactly is allowed; only crossing it returns `true`.
  """
  @spec would_exceed?(cart(), integer()) :: boolean()
  def would_exceed?(cart, added_weight) when is_map(cart) do
    current_weight(cart) + added_weight > @max_cart_weight
  end

  @spec item_weight(integer()) :: non_neg_integer()
  defp item_weight(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %{weight: weight}} -> weight
      {:error, :item_not_found} -> 0
    end
  end
end
