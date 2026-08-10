defmodule Aesir.ZoneServer.Unit.Vending do
  @moduledoc """
  Pure domain core for a merchant's vending shop.

  A vending shop sells items *from the cart* at per-item prices. This module is
  side-effect free: it validates an open request, builds the browse/board
  snapshot, and computes a purchase as plain data over the cart
  `%{index => InventoryItem.t()}` map (the same shape used by
  `Aesir.ZoneServer.Unit.Cart`). It never touches the database, sockets or
  processes; turning a computed purchase into persisted changes and packets is
  the handler's job.

  The cart is the single source of truth for stock. A shop entry references a
  cart index and listed amount/price; every purchase is revalidated against the
  *live* cart, so a slot that sold out concurrently yields `{:error, :sold_out}`.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Bound
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Rental

  @price_min 1
  @price_max 99_999_999

  @typedoc "Cart keyed by stable session index; structurally an inventory map."
  @type cart :: %{non_neg_integer() => InventoryItem.t()}

  @typedoc "A client open-shop line: `{cart_index, amount, price}`."
  @type entry :: {non_neg_integer(), pos_integer(), pos_integer()}

  @typedoc "A client buy line: `{cart_index, amount}`."
  @type buy_line :: {non_neg_integer(), pos_integer()}

  defmodule ShopItem do
    @moduledoc "A validated vending shop line, resolved against the cart at open time."

    @enforce_keys [:cart_index, :nameid, :amount, :price]
    defstruct [:cart_index, :nameid, :amount, :price]

    @type t() :: %__MODULE__{
            cart_index: non_neg_integer(),
            nameid: integer(),
            amount: pos_integer(),
            price: pos_integer()
          }
  end

  @typedoc "A browse/board row: shop listing merged with live cart display attrs."
  @type snapshot_item :: %{
          index: non_neg_integer(),
          nameid: integer(),
          amount: pos_integer(),
          price: pos_integer(),
          refine: integer(),
          cards: [integer()],
          identify: integer(),
          attribute: integer(),
          enchant_grade: integer(),
          craft: map() | nil
        }

  @typedoc "A computed purchase: total cost plus the cart/inventory deltas to apply."
  @type purchase :: %{
          total_cost: non_neg_integer(),
          cart_removals: [{non_neg_integer(), pos_integer()}],
          inventory_adds: [{InventoryItem.t(), pos_integer()}]
        }

  @doc """
  Validates an open-shop request against the live cart.

  Accepts at most `max_slots` lines. Each `{cart_index, amount, price}` must
  carry a positive amount, a `price` in `#{@price_min}..#{@price_max}`, and
  reference a cart slot holding at least `amount`. On success returns the
  resolved `ShopItem` lines (nameid taken from the cart slot).
  """
  @spec validate_open(cart(), [entry()], pos_integer()) ::
          {:ok, [ShopItem.t()]}
          | {:error,
             :too_many_slots
             | :invalid_amount
             | :invalid_price
             | :item_not_in_cart
             | :insufficient_stock
             | :item_unidentified
             | :item_bound
             | :item_rental}
  def validate_open(cart, entries, max_slots)
      when is_map(cart) and is_list(entries) and is_integer(max_slots) do
    if length(entries) > max_slots do
      {:error, :too_many_slots}
    else
      validate_entries(cart, entries)
    end
  end

  defp validate_entries(cart, entries) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case validate_entry(cart, entry) do
        {:ok, shop_item} -> {:cont, {:ok, [shop_item | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  @doc """
  Builds the browse/board snapshot for `shop_items` from the live `cart`.

  Each row carries the listing (index, nameid, amount, price) plus the display
  attributes (refine, cards, identify, ...) read from the current cart slot.
  Lines whose cart slot no longer exists are dropped.
  """
  @spec build_snapshot(cart(), [ShopItem.t()]) :: [snapshot_item()]
  def build_snapshot(cart, shop_items) when is_map(cart) and is_list(shop_items) do
    Enum.flat_map(shop_items, fn %ShopItem{} = shop ->
      case PlayerState.get_by_index(cart, shop.cart_index) do
        %InventoryItem{} = item -> [snapshot_row(shop, item)]
        nil -> []
      end
    end)
  end

  @doc """
  Computes a purchase of `buy_lines` against the shop and the live `cart`.

  Each `{cart_index, amount}` must match a shop line and a live cart slot still
  holding the listed nameid in sufficient quantity. Returns the total cost and
  the cart-removal / inventory-add deltas (the inventory adds carry the source
  cart item as a template). Returns `{:error, :bad_line}` for a line not on the
  shop (or over its listed amount) and `{:error, :sold_out}` when the live cart
  no longer holds enough.
  """
  @spec compute_purchase(cart(), [ShopItem.t()], [buy_line()]) ::
          {:ok, purchase()} | {:error, :sold_out | :bad_line}
  def compute_purchase(cart, shop_items, buy_lines)
      when is_map(cart) and is_list(shop_items) and is_list(buy_lines) do
    Enum.reduce_while(buy_lines, {:ok, {0, [], []}}, fn line, {:ok, acc} ->
      case resolve_buy(cart, shop_items, line) do
        {:ok, cost, removal, add} ->
          {total, removals, adds} = acc
          {:cont, {:ok, {total + cost, [removal | removals], [add | adds]}}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, {total, removals, adds}} ->
        {:ok,
         %{
           total_cost: total,
           cart_removals: Enum.reverse(removals),
           inventory_adds: Enum.reverse(adds)
         }}

      error ->
        error
    end
  end

  defp validate_entry(cart, {cart_index, amount, price}) do
    with :ok <- check_amount(amount),
         :ok <- check_price(price),
         {:ok, item} <- fetch_slot(cart, cart_index, amount),
         :ok <- check_identified(item),
         :ok <- check_bound(item),
         :ok <- check_rental(item) do
      {:ok, %ShopItem{cart_index: cart_index, nameid: item.nameid, amount: amount, price: price}}
    end
  end

  defp check_amount(amount) when is_integer(amount) and amount > 0, do: :ok
  defp check_amount(_), do: {:error, :invalid_amount}

  defp check_price(price) when is_integer(price) and price >= @price_min and price <= @price_max,
    do: :ok

  defp check_price(_), do: {:error, :invalid_price}

  defp fetch_slot(cart, cart_index, amount) do
    case PlayerState.get_by_index(cart, cart_index) do
      %InventoryItem{amount: held} = item when held >= amount -> {:ok, item}
      %InventoryItem{} -> {:error, :insufficient_stock}
      nil -> {:error, :item_not_in_cart}
    end
  end

  defp check_identified(item) do
    if InventoryItem.identified?(item), do: :ok, else: {:error, :item_unidentified}
  end

  defp check_bound(item) do
    if Bound.vendable?(item), do: :ok, else: {:error, :item_bound}
  end

  defp check_rental(item) do
    if Rental.transferable?(item), do: :ok, else: {:error, :item_rental}
  end

  defp snapshot_row(%ShopItem{} = shop, %InventoryItem{} = item) do
    %{
      index: shop.cart_index,
      nameid: shop.nameid,
      amount: shop.amount,
      price: shop.price,
      refine: item.refine,
      cards: InventoryItem.cards(item),
      identify: item.identify,
      attribute: item.attribute,
      enchant_grade: item.enchant_grade,
      craft: item.craft
    }
  end

  defp resolve_buy(cart, shop_items, {index, amount}) do
    with %ShopItem{} = shop <- find_line(shop_items, index),
         true <- is_integer(amount) and amount > 0 and amount <= shop.amount do
      check_stock(cart, shop, index, amount)
    else
      _ -> {:error, :bad_line}
    end
  end

  defp check_stock(cart, %ShopItem{} = shop, index, amount) do
    case PlayerState.get_by_index(cart, index) do
      %InventoryItem{nameid: nameid, amount: held} = item
      when nameid == shop.nameid and held >= amount ->
        if Bound.vendable?(item) do
          {:ok, amount * shop.price, {index, amount}, {item, amount}}
        else
          {:error, :sold_out}
        end

      _ ->
        {:error, :sold_out}
    end
  end

  defp find_line(shop_items, index) do
    Enum.find(shop_items, fn %ShopItem{cart_index: ci} -> ci == index end)
  end
end
