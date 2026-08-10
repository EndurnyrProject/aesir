defmodule Aesir.ZoneServer.Unit.Shop do
  @moduledoc """
  Pure domain core for an NPC buy/sell vendor.

  Side-effect free: it builds the open-window lists, computes a buy, and computes
  a sell as plain data over a `Npc.Shop` placement and a `PlayerState` snapshot.
  It never touches the database, sockets or processes; turning a computed buy or
  sell into persisted changes and packets is the handler's job.

  Buying is restricted to the shop's item list; selling accepts any sellable
  inventory item (`sell > 0`, not bound or favorite). Prices flow through
  `effective_buy_price/3` and `effective_sell_price/2`, keeping displayed and
  transaction prices identical.

  Stacking, free-slot and weight accounting reuse the inventory core
  (`Unit.Inventory`, `Unit.Inventory.Weight`) so a shop never re-derives them.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Npc.Shop, as: ShopData
  alias Aesir.ZoneServer.Unit.Bound
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Rental
  alias Aesir.ZoneServer.Unit.Zeny

  @discount_skill_id 37
  @overcharge_skill_id 38

  @typedoc "A buy-window row, shaped for `Aesir.Net.NpcShopBuyItem`."
  @type buy_item :: %{nameid: pos_integer(), type: non_neg_integer(), price: non_neg_integer()}

  @typedoc "A sell-window row, shaped for `Aesir.Net.NpcShopSellItem`."
  @type sell_item :: %{
          inventory_index: non_neg_integer(),
          nameid: pos_integer(),
          type: non_neg_integer(),
          amount: pos_integer(),
          sell_price: non_neg_integer()
        }

  @typedoc "A client buy line: `{nameid, amount}`."
  @type buy_request :: {pos_integer(), pos_integer()}

  @typedoc "A client sell line: `{inventory_index, amount}`."
  @type sell_request :: {non_neg_integer(), pos_integer()}

  @typedoc "A computed buy: total cost plus the item adds for the handler to persist."
  @type purchase :: %{
          total_cost: non_neg_integer(),
          item_adds: [{ItemDefinition.t(), pos_integer()}]
        }

  @typedoc "A computed sell: total credit plus the inventory removals to apply."
  @type sale :: %{
          total_credit: non_neg_integer(),
          removals: [{non_neg_integer(), pos_integer()}]
        }

  @doc """
  Builds the open-window lists: the shop's buy list and the player's sellable
  inventory, both with resolved prices.

  The buy list is the shop's items at `effective_buy_price/3`; the sell list is
  every sellable inventory slot (ordered by session index) at
  `effective_sell_price/2`. Item types are resolved to the client numeric code.
  """
  @spec build_open(ShopData.t(), PlayerState.t()) :: {[buy_item()], [sell_item()]}
  def build_open(%ShopData{} = shop, %PlayerState{inventory: inventory} = player_state) do
    {build_buy_items(shop, player_state), build_sell_items(inventory, player_state)}
  end

  @doc """
  Computes a buy of `requests` against the shop and the player's snapshot.

  Each `{nameid, amount}` must reference an item on the shop's list. Returns the
  summed cost and the `{item_def, amount}` adds, or the first failing gate:
  `:item_not_in_shop`, `:not_enough_zeny`, `:overweight`, or `:no_slots`.
  """
  @spec compute_buy(ShopData.t(), [buy_request()], PlayerState.t()) ::
          {:ok, purchase()}
          | {:error, :item_not_in_shop | :not_enough_zeny | :overweight | :no_slots}
  def compute_buy(%ShopData{} = shop, requests, %PlayerState{} = player_state)
      when is_list(requests) do
    with {:ok, lines} <- resolve_buy_lines(shop, requests, player_state),
         total_cost = total_cost(lines),
         :ok <- ensure_zeny(player_state.zeny, total_cost),
         :ok <- ensure_weight(player_state.inventory, player_state.stats, lines),
         :ok <- ensure_slots(player_state.inventory, lines) do
      {:ok,
       %{
         total_cost: total_cost,
         item_adds: Enum.map(lines, fn {def, amount, _} -> {def, amount} end)
       }}
    end
  end

  @doc """
  Computes a sell of `requests` against the player's inventory snapshot.

  Each `{inventory_index, amount}` must reference an owned slot holding at least
  `amount` of a sellable item. Returns the summed credit (clamped to `Unit.Zeny.max_zeny/0`)
  and the `{inventory_index, amount}` removals, or the first failing line:
  `:invalid_item`, `:insufficient_amount`, or `:unsellable`. Selling is not
  restricted to the shop's item list.
  """
  @spec compute_sell([sell_request()], PlayerState.t()) ::
          {:ok, sale()} | {:error, :invalid_item | :insufficient_amount | :unsellable}
  def compute_sell(requests, %PlayerState{inventory: inventory} = player_state)
      when is_list(requests) do
    with {:ok, total_credit, removals} <-
           resolve_sell_lines(inventory, requests, player_state) do
      {:ok, %{total_credit: min(total_credit, Zeny.max_zeny()), removals: removals}}
    end
  end

  @doc """
  The buy price for `nameid` at this shop: the per-item override when present,
  otherwise `ItemDefinition.buy`. The Discount choke point.
  """
  @spec effective_buy_price(ShopData.t(), pos_integer(), PlayerState.t()) :: non_neg_integer()
  def effective_buy_price(%ShopData{items: items, discount: discount}, nameid, player_state) do
    base_price =
      case Enum.find(items, &(&1.nameid == nameid)) do
        %{price: price} when is_integer(price) -> price
        _ -> base_buy(nameid)
      end

    if discount do
      discount_pct =
        max(
          skill_rate(player_state, @discount_skill_id),
          Passives.shop_discount_pct(player_state)
        )

      max(1, apply_rate(base_price, -discount_pct))
    else
      base_price
    end
  end

  @doc """
  The sell price for `nameid`, including the standard buy-price fallback when
  the explicit sell value is unset, adjusted by Overcharge.
  """
  @spec effective_sell_price(pos_integer(), PlayerState.t()) :: non_neg_integer()
  def effective_sell_price(nameid, player_state) do
    base_price =
      case ItemManagement.get_item_by_id(nameid) do
        {:ok, %ItemDefinition{} = def} -> ItemDefinition.sell_price(def)
        {:error, _} -> 0
      end

    apply_rate(base_price, skill_rate(player_state, @overcharge_skill_id))
  end

  defp base_buy(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{buy: buy}} -> buy
      {:error, _} -> 0
    end
  end

  defp build_buy_items(%ShopData{items: items} = shop, player_state) do
    Enum.flat_map(items, fn %{nameid: nameid} ->
      case ItemManagement.get_item_by_id(nameid) do
        {:ok, %ItemDefinition{type: type}} ->
          [
            %{
              nameid: nameid,
              type: ClientItemType.to_client_type(type),
              price: effective_buy_price(shop, nameid, player_state)
            }
          ]

        {:error, _} ->
          []
      end
    end)
  end

  defp build_sell_items(inventory, player_state) do
    inventory
    |> Enum.sort_by(fn {index, _item} -> index end)
    |> Enum.flat_map(fn {index, %InventoryItem{} = item} ->
      case sellable(item) do
        {:ok, %ItemDefinition{type: type}} ->
          [
            %{
              inventory_index: index,
              nameid: item.nameid,
              type: ClientItemType.to_client_type(type),
              amount: item.amount,
              sell_price: effective_sell_price(item.nameid, player_state)
            }
          ]

        {:error, _} ->
          []
      end
    end)
  end

  defp resolve_buy_lines(shop, requests, player_state) do
    requests
    |> Enum.reduce_while({:ok, []}, fn request, {:ok, acc} ->
      case resolve_buy_line(shop, request, player_state) do
        {:ok, line} -> {:cont, {:ok, [line | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, lines} -> {:ok, Enum.reverse(lines)}
      error -> error
    end
  end

  defp resolve_buy_line(%ShopData{} = shop, {nameid, amount}, player_state)
       when is_integer(amount) and amount > 0 do
    with true <- in_shop?(shop, nameid),
         {:ok, %ItemDefinition{} = def} <- ItemManagement.get_item_by_id(nameid) do
      {:ok, {def, amount, effective_buy_price(shop, nameid, player_state)}}
    else
      _ -> {:error, :item_not_in_shop}
    end
  end

  defp resolve_buy_line(_shop, _request, _player_state), do: {:error, :item_not_in_shop}

  defp in_shop?(%ShopData{items: items}, nameid), do: Enum.any?(items, &(&1.nameid == nameid))

  defp total_cost(lines) do
    Enum.reduce(lines, 0, fn {_def, amount, price}, acc -> acc + price * amount end)
  end

  defp ensure_zeny(zeny, cost) when zeny >= cost, do: :ok
  defp ensure_zeny(_zeny, _cost), do: {:error, :not_enough_zeny}

  defp ensure_weight(inventory, stats, lines) do
    added =
      Enum.reduce(lines, 0, fn {%ItemDefinition{weight: weight}, amount, _}, acc ->
        acc + weight * amount
      end)

    if Weight.would_exceed?(inventory, stats, added),
      do: {:error, :overweight},
      else: :ok
  end

  defp ensure_slots(inventory, lines) do
    lines
    |> Enum.reduce_while({:ok, inventory}, fn {def, amount, _}, {:ok, inv} ->
      case Inventory.add(inv, def, amount) do
        {:ok, new_inv, _change} -> {:cont, {:ok, new_inv}}
        {:error, :inventory_full} -> {:halt, {:error, :no_slots}}
      end
    end)
    |> case do
      {:ok, _inventory} -> :ok
      error -> error
    end
  end

  defp resolve_sell_lines(inventory, requests, player_state) do
    requests
    |> Enum.reduce_while({:ok, 0, []}, fn request, {:ok, total, removals} ->
      case resolve_sell_line(inventory, request, player_state) do
        {:ok, credit, removal} -> {:cont, {:ok, total + credit, [removal | removals]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, total, removals} -> {:ok, total, Enum.reverse(removals)}
      error -> error
    end
  end

  defp resolve_sell_line(inventory, {index, amount}, player_state)
       when is_integer(amount) and amount > 0 do
    with %InventoryItem{} = item <- fetch_owned(inventory, index, amount),
         {:ok, %ItemDefinition{}} <- sellable(item) do
      {:ok, effective_sell_price(item.nameid, player_state) * amount, {index, amount}}
    end
  end

  defp resolve_sell_line(_inventory, _request, _player_state), do: {:error, :invalid_item}

  defp fetch_owned(inventory, index, amount) do
    case PlayerState.get_by_index(inventory, index) do
      %InventoryItem{amount: held} = item when held >= amount -> item
      %InventoryItem{} -> {:error, :insufficient_amount}
      nil -> {:error, :invalid_item}
    end
  end

  defp sellable(%InventoryItem{equip: equip, favorite: favorite})
       when equip != 0 or favorite != 0,
       do: {:error, :unsellable}

  defp sellable(%InventoryItem{nameid: nameid} = item) do
    with true <- Bound.sellable?(item),
         true <- Rental.transferable?(item),
         {:ok, %ItemDefinition{} = def} <- ItemManagement.get_item_by_id(nameid),
         true <- ItemDefinition.sell_price(def) > 0 do
      {:ok, def}
    else
      _ -> {:error, :unsellable}
    end
  end

  defp apply_rate(price, rate), do: div(price * (100 + rate), 100)

  defp skill_rate(%PlayerState{stats: %{progression: %{learned_skills: learned}}}, skill_id) do
    case Learned.learned_level(learned, skill_id) do
      0 ->
        0

      level ->
        rate = 5 + 2 * level - if(level == 10, do: 1, else: 0)
        rate |> min(100) |> max(0)
    end
  end
end
