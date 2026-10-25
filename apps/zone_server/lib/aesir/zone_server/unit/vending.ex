defmodule Aesir.ZoneServer.Unit.Vending do
  @moduledoc """
  Pure domain core for a merchant's vending shop.

  A vending shop sells items *from the cart* at per-item prices. This module is
  side-effect free through its policy-aware interface: it validates an open
  request, builds the browse/board snapshot, and computes a purchase over the cart
  `%{index => InventoryItem.t()}` map (the same shape used by
  `Aesir.ZoneServer.Unit.Cart`). It never touches the database, sockets or
  processes; turning a computed purchase into persisted changes and packets is
  the handler's job.

  The cart is the single source of truth for stock. A shop entry references a
  cart index and listed amount/price; every purchase is revalidated against the
  *live* cart, so a slot that sold out concurrently yields `{:error, :sold_out}`.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Unit.Bound
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Rental
  alias Aesir.ZoneServer.Unit.Zeny

  @price_min 0
  @max_wire_price 4_294_967_295

  @typedoc "Vending price, listing balance, tax and buyer-name policy."
  @type rules :: %{
          max_price: non_neg_integer(),
          allow_over_max: boolean(),
          tax: non_neg_integer(),
          tax_min: non_neg_integer(),
          show_buyer_name: boolean()
        }

  @typedoc "Cart keyed by stable session index; structurally an inventory map."
  @type cart :: %{non_neg_integer() => InventoryItem.t()}

  @typedoc "A client open-shop line: `{cart_index, amount, price}`."
  @type entry :: {non_neg_integer(), pos_integer(), non_neg_integer()}

  @typedoc "A client buy line: `{cart_index, amount}`."
  @type buy_line :: {non_neg_integer(), pos_integer()}

  defmodule ShopItem do
    @moduledoc "A validated vending shop line, resolved against the cart at open time."

    @enforce_keys [:cart_index, :nameid, :amount, :price]
    defstruct [:cart_index, :nameid, :amount, :price, bound: 0]

    @type t() :: %__MODULE__{
            cart_index: non_neg_integer(),
            nameid: integer(),
            amount: pos_integer(),
            price: non_neg_integer(),
            bound: non_neg_integer()
          }
  end

  @typedoc "A browse/board row: shop listing merged with live cart display attrs."
  @type snapshot_item :: %{
          index: non_neg_integer(),
          nameid: integer(),
          amount: pos_integer(),
          price: non_neg_integer(),
          refine: integer(),
          cards: [integer()],
          identify: integer(),
          attribute: integer(),
          enchant_grade: integer(),
          craft: map() | nil,
          random_options: ItemOptions.t()
        }

  @typedoc "A computed purchase: total cost plus the cart/inventory deltas to apply."
  @type purchase :: %{
          total_cost: non_neg_integer(),
          cart_removals: [{non_neg_integer(), pos_integer()}],
          inventory_adds: [{InventoryItem.t(), pos_integer()}]
        }

  @doc """
  Validates listings with runtime rules and ordinary bound-item permissions.

  Session callers with explicit permissions use `validate_open/4` instead.
  This compatibility entry point reads configuration but never changes state.
  """
  @spec validate_open(cart(), [entry()], pos_integer()) ::
          {:ok, [ShopItem.t()]} | {:error, atom()}
  def validate_open(cart, entries, max_slots) do
    context = %{
      rules: Config.vending_rules(),
      seller_zeny: 0,
      eligibility: Map.new(cart, fn {index, item} -> {index, check_bound(item)} end)
    }

    validate_open(cart, entries, max_slots, context)
  end

  @doc """
  Validates live stock with explicit policy and permission-aware slot eligibility.

  Prices are nonnegative unsigned wire values, capped to the configured maximum.
  Eligibility maps each raw cart slot to `:ok` or its specific refusal reason.
  """
  @spec validate_open(cart(), [entry()], pos_integer(), map()) ::
          {:ok, [ShopItem.t()]} | {:error, atom()}
  def validate_open(cart, entries, max_slots, context)
      when is_map(cart) and is_list(entries) and is_integer(max_slots) do
    cond do
      entries == [] -> {:error, :no_items}
      length(entries) > min(max_slots, 12) -> {:error, :too_many_slots}
      length(Enum.uniq_by(entries, &elem(&1, 0))) != length(entries) -> {:error, :duplicate_slot}
      true -> validate_entries(cart, entries, context)
    end
  end

  defp validate_entries(cart, entries, context) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case validate_entry(cart, entry, context) do
        {:ok, shop_item} -> {:cont, {:ok, [shop_item | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> validate_listing_balance(Enum.reverse(items), context)
      error -> error
    end
  end

  defp validate_listing_balance(items, %{rules: %{allow_over_max: true}}), do: {:ok, items}

  defp validate_listing_balance(items, %{seller_zeny: zeny}) do
    total = Enum.reduce(items, 0, fn item, sum -> sum + item.amount * item.price end)

    if zeny + total > Zeny.max_zeny(), do: {:error, :zeny_limit}, else: {:ok, items}
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
  cart item as a template). Duplicate lines share a cumulative stock allowance.
  Missing listings return `:bad_line`, excess listed quantities return
  `:insufficient_stock`, and changed live cart stock returns `:sold_out`.
  """
  @spec compute_purchase(cart(), [ShopItem.t()], [buy_line()]) ::
          {:ok, purchase()} | {:error, atom()}
  def compute_purchase(_cart, shop_items, buy_lines)
      when buy_lines == [] or length(buy_lines) > 12 or length(buy_lines) > length(shop_items),
      do: {:error, :invalid_amount}

  def compute_purchase(cart, shop_items, buy_lines)
      when is_map(cart) and is_list(shop_items) and is_list(buy_lines) do
    with {:ok, collapsed} <- collapse_purchase_lines(buy_lines) do
      compute_purchase_lines(cart, shop_items, Enum.sort(collapsed))
    end
  end

  defp collapse_purchase_lines(lines) do
    Enum.reduce_while(lines, {:ok, %{}}, fn {index, amount}, {:ok, totals} ->
      case check_amount(amount) do
        :ok -> {:cont, {:ok, Map.update(totals, index, amount, &(&1 + amount))}}
        error -> {:halt, error}
      end
    end)
  end

  defp compute_purchase_lines(cart, shop_items, buy_lines) do
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

  @doc "Checks intrinsic identification, broken and rental restrictions, without group policy."
  @spec intrinsic_eligibility(InventoryItem.t()) :: :ok | {:error, atom()}
  def intrinsic_eligibility(%InventoryItem{} = item) do
    with :ok <- check_identified(item),
         :ok <- check_unbroken(item) do
      check_rental(item)
    end
  end

  @doc "Normalizes a nonempty, control-free title to at most 79 valid UTF-8 bytes."
  @spec normalize_title(String.t()) :: {:ok, String.t()} | {:error, :invalid_title}
  def normalize_title(title) when is_binary(title) do
    if title != "" and String.valid?(title) and not Regex.match?(~r/\p{Cc}/u, title) do
      {:ok, String.byte_slice(title, 0, 79)}
    else
      {:error, :invalid_title}
    end
  end

  @doc "Net seller credit after the basket's threshold check and final truncation."
  @spec seller_credit(non_neg_integer(), rules()) :: non_neg_integer()
  def seller_credit(total, %{tax: rate, tax_min: minimum})
      when rate in 0..10_000 and total >= 0 do
    if rate > 0 and total >= minimum do
      trunc(total - total * (rate / 10_000))
    else
      total
    end
  end

  defp validate_entry(cart, {cart_index, amount, price}, context) do
    with :ok <- check_amount(amount),
         {:ok, price} <- normalize_price(price, context.rules.max_price),
         {:ok, item} <- fetch_slot(cart, cart_index, amount),
         :ok <- intrinsic_eligibility(item),
         :ok <- Map.get(context.eligibility, cart_index, {:error, :item_untradeable}) do
      {:ok,
       %ShopItem{
         cart_index: cart_index,
         nameid: item.nameid,
         amount: amount,
         price: price,
         bound: item.bound
       }}
    end
  end

  defp check_amount(amount) when is_integer(amount) and amount > 0, do: :ok
  defp check_amount(_), do: {:error, :invalid_amount}

  defp normalize_price(price, max_price)
       when is_integer(price) and price >= @price_min and price <= @max_wire_price,
       do: {:ok, min(price, max_price)}

  defp normalize_price(_, _), do: {:error, :invalid_price}

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

  defp check_unbroken(%InventoryItem{attribute: 1}), do: {:error, :item_broken}
  defp check_unbroken(%InventoryItem{}), do: :ok

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
      craft: item.craft,
      random_options: item.random_options
    }
  end

  defp resolve_buy(cart, shop_items, {index, amount}) do
    with %ShopItem{} = shop <- find_line(shop_items, index),
         true <- is_integer(amount) and amount > 0 and amount <= shop.amount do
      check_stock(cart, shop, index, amount)
    else
      nil -> {:error, :bad_line}
      false -> {:error, :insufficient_stock}
    end
  end

  defp check_stock(cart, %ShopItem{} = shop, index, amount) do
    case PlayerState.get_by_index(cart, index) do
      %InventoryItem{nameid: nameid, amount: held} = item
      when nameid == shop.nameid and held >= amount ->
        if item.bound == shop.bound do
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
