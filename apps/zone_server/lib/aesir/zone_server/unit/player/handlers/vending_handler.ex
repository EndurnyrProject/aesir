defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler do
  @moduledoc """
  Opens and closes a merchant's vending shop (design "Open-shop flow" /
  "Close-shop flow").

  `PlayerSession` is the single writer; both functions take and return the
  session `state` map and run inside a session cast. Opening gates on a mounted
  cart (`SC_PUSHCART` active) and a learned `MC_VENDING`, validates the listing
  through the pure `Vending` core, enters the frozen `:vending` action state with
  the shop carried in `state_context`, mirrors the shop into the `Vending.Registry`
  for out-of-session browse/board reads, and area-broadcasts the title board.
  Closing tears the shop down and returns to `:idle`; unsold stock simply stays
  in the cart (no item move).
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingOpenResult
  alias Aesir.Net.VendingSaleReport
  alias Aesir.Net.VendingShopItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.McVending
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight, as: InventoryWeight
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending
  alias Aesir.ZoneServer.Unit.Vending.Registry
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  @push_cart_status :sc_push_cart
  @mc_vending_id McVending.definition().id
  @max_zeny 1_000_000_000

  @typedoc "The live shop carried in `:vending` `state_context` and the registry."
  @type shop :: %{title: String.t(), owner_char_id: integer(), items: [ShopItem.t()]}

  @typedoc """
  What the buyer session needs to reconcile after the seller-authoritative buy:
  the fully persisted buyer inventory map (rows carry their real DB ids), the
  per-add change descriptors (so the buyer emits one `ItemAdded` per touched
  slot), and the zeny already debited inside the seller's transaction.
  """
  @type buyer_delta :: %{
          inventory: Inventory.t(),
          item_changes: [Inventory.change()],
          zeny_spent: non_neg_integer()
        }

  @type state :: %{
          required(:connection_pid) => pid(),
          required(:game_state) => PlayerState.t(),
          optional(atom()) => term()
        }

  @doc """
  Opens a vending shop selling `entries` (`{cart_index, amount, price}` lines)
  from the mounted cart under `title`.

  Requires the cart mounted (`SC_PUSHCART` active) and `MC_VENDING` learned; the
  learned level caps the line count via `McVending.max_slots/1`. On success it
  validates through `Vending.validate_open/3`, transitions to `:vending` with the
  shop in `state_context`, registers the shop, broadcasts `VendingBoardShown` to
  in-range players, and returns `{:ok, state}`. On any failure it returns a typed
  error and leaves the session, registry and clients untouched.
  """
  @spec open_shop(state(), String.t(), [Vending.entry()]) ::
          {:ok, state()}
          | {:error,
             :no_cart
             | :skill_not_learned
             | :too_many_slots
             | :invalid_amount
             | :invalid_price
             | :item_not_in_cart
             | :insufficient_stock
             | :invalid_transition}
  def open_shop(%{game_state: gs} = state, title, entries) do
    char_id = gs.character_id

    with :ok <- ensure_cart_mounted(char_id),
         {:ok, level} <- ensure_vending_learned(gs),
         {:ok, shop_items} <- Vending.validate_open(gs.cart, entries, McVending.max_slots(level)),
         shop = %{title: title, owner_char_id: char_id, items: shop_items},
         {:ok, new_gs} <- PlayerState.transition_to(gs, :vending, shop) do
      Registry.put(char_id, self(), shop)
      broadcast_board(new_gs, %VendingBoardShown{unit_id: char_id, title: title})
      {:ok, %{state | game_state: new_gs}}
    end
  end

  @doc """
  Closes the shop for `reason`.

  Removes the registry entry, broadcasts `VendingBoardRemoved` to in-range
  players, and returns to `:idle`. Unsold stock stays in the cart — no item is
  moved. Returns `{:ok, state}`.

  A safe no-op when the session is not currently in `:vending` (e.g. the
  defensive `terminate/2` teardown of a non-vending session), so it never
  `MatchError`s on the `:idle` transition.
  """
  @spec close_shop(state(), atom()) :: {:ok, state()}
  def close_shop(%{game_state: %{action_state: :vending} = gs} = state, reason) do
    char_id = gs.character_id
    Logger.debug("Closing vending shop for #{char_id}: #{inspect(reason)}")

    Registry.remove(char_id)
    broadcast_board(gs, %VendingBoardRemoved{unit_id: char_id})

    {:ok, new_gs} = PlayerState.transition_to(gs, :idle)
    {:ok, %{state | game_state: new_gs}}
  end

  def close_shop(state, _reason), do: {:ok, state}

  @doc """
  Session-facing wrapper for `open_shop/3`: commits the new game state to the
  unit registry and confirms with `VendingOpenResult{ok: true}` on success, or
  logs the failure and tells the client with `VendingOpenResult{ok: false}`
  carrying the rejection code.
  """
  @spec handle_open(state(), String.t(), [Vending.entry()]) :: {:noreply, state()}
  def handle_open(state, title, entries) do
    case open_shop(state, title, entries) do
      {:ok, new_state} ->
        MessageRouter.send_to(state.connection_pid, %VendingOpenResult{result: :VEND_OK})
        {:noreply, sync_game_state(new_state)}

      {:error, reason} ->
        Logger.debug(
          "Vending open failed for #{state.game_state.character_id}: #{inspect(reason)}"
        )

        MessageRouter.send_to(state.connection_pid, %VendingOpenResult{result: open_code(reason)})

        {:noreply, state}
    end
  end

  @spec open_code(atom()) :: atom()
  defp open_code(:no_cart), do: :VEND_NO_CART
  defp open_code(:skill_not_learned), do: :VEND_SKILL_NOT_LEARNED
  defp open_code(:too_many_slots), do: :VEND_TOO_MANY_SLOTS
  defp open_code(:invalid_amount), do: :VEND_INVALID_AMOUNT
  defp open_code(:invalid_price), do: :VEND_INVALID_PRICE
  defp open_code(:item_not_in_cart), do: :VEND_ITEM_NOT_IN_CART
  defp open_code(:insufficient_stock), do: :VEND_INSUFFICIENT_STOCK
  defp open_code(_reason), do: :VEND_INVALID_STATE

  @doc """
  Session-facing wrapper for `close_shop/2` with the `:user_closed` reason.
  """
  @spec handle_close(state()) :: {:noreply, state()}
  def handle_close(state) do
    {:ok, new_state} = close_shop(state, :user_closed)
    {:noreply, sync_game_state(new_state)}
  end

  @doc """
  Session-facing wrapper for `build_list/1`: replies with the `VendingList`
  when the vendor's shop is live, silently drops otherwise.
  """
  @spec handle_list(state(), integer()) :: {:noreply, state()}
  def handle_list(state, vendor_unit_id) do
    case build_list(vendor_unit_id) do
      {:ok, packet} -> MessageRouter.send_to(state.connection_pid, packet)
      :error -> :ok
    end

    {:noreply, state}
  end

  @doc """
  Runs a purchase from the buyer session: parks a `call` on the seller session
  (the transactional authority) and reconciles the returned buyer delta via
  `apply_purchase_as_buyer/2`. Any failure logs and leaves the buyer untouched.
  """
  @spec handle_purchase_request(state(), integer(), [{non_neg_integer(), pos_integer()}]) ::
          {:noreply, state()}
  def handle_purchase_request(%{game_state: gs} = buyer_state, vendor_unit_id, buy_lines) do
    with :ok <- reject_self_purchase(vendor_unit_id, gs.character_id),
         {:ok, seller_pid} <- UnitRegistry.get_player_pid(vendor_unit_id),
         {:ok, buyer_delta} <-
           GenServer.call(
             seller_pid,
             {:vending_purchase, gs.character_id, gs.inventory, gs.zeny, gs.stats,
              gs.character_name, buy_lines}
           ),
         {:ok, new_state} <- apply_purchase_as_buyer(buyer_state, buyer_delta) do
      {:noreply, sync_game_state(new_state)}
    else
      {:error, reason} ->
        Logger.debug("Vending purchase failed for #{gs.character_id}: #{inspect(reason)}")
        {:noreply, buyer_state}
    end
  end

  # A player can't buy from their own shop; resolving the seller to self() would
  # also deadlock the GenServer.call until its 5s timeout crashed the session.
  defp reject_self_purchase(char_id, char_id), do: {:error, :self_purchase}
  defp reject_self_purchase(_vendor_unit_id, _char_id), do: :ok

  # Mirrors the session's registry sync: any wrapper that commits a new
  # game_state must also publish it to the unit registry.
  defp sync_game_state(%{game_state: gs} = state) do
    UnitRegistry.update_unit_state(:player, gs.character_id, gs)
    state
  end

  @doc """
  Buys `buy_lines` from this seller's live shop, the sole transactional authority.

  Runs in the **seller** session (the single writer of its own cart and zeny). The
  buyer's snapshot (`buyer_char_id`, `buyer_inventory`, `buyer_zeny`,
  `buyer_stats`, `buyer_name`) is passed in from the parked buyer `call`, so it is
  fresh. Duplicate `buy_lines` on the same cart index are accumulated before
  validation, so the total requested per slot is checked once against live stock
  (no over-sell across lines). It then revalidates against the *live* cart via
  `Vending.compute_purchase/3`, gates on buyer funds, the seller `MAX_ZENY` credit
  cap and buyer carry weight, and commits all four row sets — seller cart
  removals, seller zeny credit, buyer inventory inserts/stacks, buyer zeny debit —
  inside **one** `Repo.transact`, so any failure rolls back the whole buy.

  On commit it updates the seller's in-memory cart/zeny, pushes the seller's own
  `CartItemRemoved` + zeny `ParamChange`, refreshes (or, when the shop is now
  empty, auto-closes) the registry entry, and returns
  `{:ok, seller_state, buyer_delta, sale_reports}`. The buyer applies `buyer_delta`
  via `apply_purchase_as_buyer/2`; `sale_reports` is one `VendingSaleReport` per
  sold line for the caller to deliver to the seller's client.
  """
  @spec purchase(
          state(),
          integer(),
          Inventory.t(),
          non_neg_integer(),
          Stats.t(),
          String.t(),
          [Vending.buy_line()]
        ) ::
          {:ok, state(), buyer_delta(), [VendingSaleReport.t()]}
          | {:error,
             :not_vending
             | :sold_out
             | :bad_line
             | :not_enough_zeny
             | :overweight
             | :zeny_overflow}
  def purchase(
        %{game_state: seller_gs} = seller_state,
        buyer_char_id,
        buyer_inventory,
        buyer_zeny,
        %Stats{} = buyer_stats,
        buyer_name,
        buy_lines
      )
      when is_integer(buyer_char_id) and is_map(buyer_inventory) and is_integer(buyer_zeny) and
             is_list(buy_lines) do
    collapsed = collapse_lines(buy_lines)

    with {:ok, shop} <- fetch_shop(seller_gs),
         {:ok, plan} <- Vending.compute_purchase(seller_gs.cart, shop.items, collapsed),
         :ok <- ensure_buyer_funds(buyer_zeny, plan.total_cost),
         :ok <- ensure_seller_zeny_cap(seller_gs.zeny, plan.total_cost),
         :ok <- ensure_buyer_capacity(buyer_inventory, buyer_stats, plan.inventory_adds),
         {:ok, persisted_cart, persisted_inv, inv_changes} <-
           transact_purchase(seller_gs, buyer_char_id, buyer_inventory, buyer_zeny, plan) do
      finalize(seller_state, shop, collapsed, plan, persisted_cart, persisted_inv, inv_changes,
        buyer_name: buyer_name
      )
    end
  end

  @doc """
  Applies the seller-computed `buyer_delta` to the buyer's in-memory session.

  The DB rows (inventory inserts/stacks + zeny debit) were already committed by
  the seller's transaction, so this only reconciles in-memory state and pushes the
  buyer's client packets: it adopts the persisted inventory map, debits the spent
  zeny, emits one `ItemAdded` per touched slot, and a zeny `ParamChange`. Returns
  `{:ok, buyer_state}`.
  """
  @spec apply_purchase_as_buyer(state(), buyer_delta()) :: {:ok, state()}
  def apply_purchase_as_buyer(%{game_state: gs} = state, %{
        inventory: inventory,
        item_changes: changes,
        zeny_spent: zeny_spent
      }) do
    new_zeny = gs.zeny - zeny_spent
    new_gs = %{gs | inventory: inventory, zeny: new_zeny}

    notify_buyer_added(state.connection_pid, inventory, changes)
    StatusSync.send_param(state.connection_pid, StatusParams.zeny(), new_zeny)

    {:ok, %{state | game_state: new_gs}}
  end

  @doc """
  Builds the `VendingList` browse reply for `vendor_unit_id`.

  Reads the vendor's live `PlayerState` (for the current cart) and the open shop
  from the `Vending.Registry`, then merges them into the display snapshot via the
  pure `Vending.build_snapshot/2`. Returns `:error` when the vendor is gone or has
  no shop open. Pure read — it never mutates the vendor session.
  """
  @spec build_list(integer()) :: {:ok, VendingList.t()} | :error
  def build_list(vendor_unit_id) do
    with {:ok, {_module, %PlayerState{cart: cart}, _pid}} <-
           UnitRegistry.get_unit(:player, vendor_unit_id),
         {:ok, %{title: title, items: items}} <- Registry.get(vendor_unit_id) do
      shop_items = Enum.map(Vending.build_snapshot(cart, items), &to_shop_item/1)
      {:ok, %VendingList{vendor_unit_id: vendor_unit_id, title: title, items: shop_items}}
    else
      _ -> :error
    end
  end

  @spec to_shop_item(Vending.snapshot_item()) :: VendingShopItem.t()
  defp to_shop_item(row) do
    %VendingShopItem{
      index: row.index,
      nameid: row.nameid,
      type: client_type(row.nameid),
      amount: row.amount,
      identified: row.identify == 1,
      attribute: row.attribute,
      refine: row.refine,
      cards: row.cards,
      price: row.price
    }
  end

  @spec client_type(integer()) :: non_neg_integer()
  defp client_type(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{type: type}} -> ClientItemType.to_client_type(type)
      {:error, _} -> ClientItemType.to_client_type(:etc)
    end
  end

  @spec collapse_lines([Vending.buy_line()]) :: [Vending.buy_line()]
  defp collapse_lines(buy_lines) do
    buy_lines
    |> Enum.reduce(%{}, fn {index, amount}, acc ->
      Map.update(acc, index, amount, &(&1 + amount))
    end)
    |> Enum.sort()
  end

  @spec fetch_shop(PlayerState.t()) :: {:ok, shop()} | {:error, :not_vending}
  defp fetch_shop(%{state_context: %{items: items} = shop}) when is_list(items), do: {:ok, shop}
  defp fetch_shop(_), do: {:error, :not_vending}

  @spec ensure_buyer_funds(non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, :not_enough_zeny}
  defp ensure_buyer_funds(buyer_zeny, cost) when buyer_zeny >= cost, do: :ok
  defp ensure_buyer_funds(_buyer_zeny, _cost), do: {:error, :not_enough_zeny}

  @spec ensure_seller_zeny_cap(non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, :zeny_overflow}
  defp ensure_seller_zeny_cap(seller_zeny, cost) do
    if seller_zeny + cost > @max_zeny, do: {:error, :zeny_overflow}, else: :ok
  end

  @spec ensure_buyer_capacity(Inventory.t(), Stats.t(), [{InventoryItem.t(), pos_integer()}]) ::
          :ok | {:error, :overweight}
  defp ensure_buyer_capacity(inventory, %Stats{} = stats, adds) do
    if InventoryWeight.would_exceed?(inventory, stats, added_weight(adds)),
      do: {:error, :overweight},
      else: :ok
  end

  @spec added_weight([{InventoryItem.t(), pos_integer()}]) :: non_neg_integer()
  defp added_weight(adds) do
    Enum.reduce(adds, 0, fn {%InventoryItem{nameid: nameid}, amount}, acc ->
      case ItemManagement.get_item_by_id(nameid) do
        {:ok, %ItemDefinition{weight: weight}} -> acc + weight * amount
        {:error, _} -> acc
      end
    end)
  end

  @spec transact_purchase(
          PlayerState.t(),
          integer(),
          Inventory.t(),
          non_neg_integer(),
          Vending.purchase()
        ) ::
          {:ok, Cart.t(), Inventory.t(), [Inventory.change()]} | {:error, term()}
  defp transact_purchase(seller_gs, buyer_char_id, buyer_inventory, buyer_zeny, plan) do
    seller_char_id = seller_gs.character_id
    new_seller_zeny = seller_gs.zeny + plan.total_cost
    new_buyer_zeny = buyer_zeny - plan.total_cost

    result =
      Repo.transact(fn ->
        with {:ok, cart} <-
               apply_cart_removals(seller_char_id, seller_gs.cart, plan.cart_removals),
             {:ok, _} <-
               CharacterPersistence.update_character(seller_char_id, %{zeny: new_seller_zeny}),
             {:ok, inv, changes} <-
               apply_buyer_adds(buyer_char_id, buyer_inventory, plan.inventory_adds),
             {:ok, _} <-
               CharacterPersistence.update_character(buyer_char_id, %{zeny: new_buyer_zeny}) do
          {:ok, {cart, inv, changes}}
        end
      end)

    case result do
      {:ok, {cart, inv, changes}} -> {:ok, cart, inv, changes}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec apply_cart_removals(integer(), Cart.t(), [{non_neg_integer(), pos_integer()}]) ::
          {:ok, Cart.t()} | {:error, term()}
  defp apply_cart_removals(char_id, cart, removals) do
    Enum.reduce_while(removals, {:ok, cart}, fn {index, amount}, {:ok, current} ->
      with {:ok, new_cart, change} <- Cart.remove(current, index, amount),
           {:ok, persisted} <- CartOps.apply_change(char_id, current, new_cart, change) do
        {:cont, {:ok, persisted}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec apply_buyer_adds(integer(), Inventory.t(), [{InventoryItem.t(), pos_integer()}]) ::
          {:ok, Inventory.t(), [Inventory.change()]} | {:error, term()}
  defp apply_buyer_adds(char_id, inventory, adds) do
    Enum.reduce_while(adds, {:ok, inventory, []}, fn {source, amount}, {:ok, current, changes} ->
      with {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(source.nameid),
           {:ok, new_inv, change} <-
             ItemContainer.add_preserving(current, item_def, amount, Inventory.capacity(), source),
           {:ok, persisted} <- InventoryOps.apply_change(char_id, current, new_inv, change) do
        {:cont, {:ok, persisted, [change | changes]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inventory, changes} -> {:ok, inventory, Enum.reverse(changes)}
      error -> error
    end
  end

  @spec finalize(
          state(),
          shop(),
          [Vending.buy_line()],
          Vending.purchase(),
          Cart.t(),
          Inventory.t(),
          [Inventory.change()],
          [{:buyer_name, String.t()}]
        ) :: {:ok, state(), buyer_delta(), [VendingSaleReport.t()]}
  defp finalize(seller_state, shop, collapsed, plan, persisted_cart, persisted_inv, inv_changes,
         buyer_name: buyer_name
       ) do
    %{game_state: seller_gs} = seller_state
    new_seller_zeny = seller_gs.zeny + plan.total_cost
    new_gs = %{seller_gs | cart: persisted_cart, zeny: new_seller_zeny}

    notify_seller(seller_state.connection_pid, plan.cart_removals, new_seller_zeny)

    sale_reports = build_sale_reports(shop, plan.cart_removals, buyer_name)

    buyer_delta = %{
      inventory: persisted_inv,
      item_changes: inv_changes,
      zeny_spent: plan.total_cost
    }

    remaining_items = reduce_shop_items(shop.items, collapsed)

    seller_state = refresh_or_close(%{seller_state | game_state: new_gs}, shop, remaining_items)
    {:ok, seller_state, buyer_delta, sale_reports}
  end

  @spec reduce_shop_items([ShopItem.t()], [Vending.buy_line()]) :: [ShopItem.t()]
  defp reduce_shop_items(items, collapsed) do
    sold = Map.new(collapsed)

    items
    |> Enum.map(fn %ShopItem{cart_index: index, amount: amount} = item ->
      %{item | amount: amount - Map.get(sold, index, 0)}
    end)
    |> Enum.reject(fn %ShopItem{amount: amount} -> amount <= 0 end)
  end

  @spec refresh_or_close(state(), shop(), [ShopItem.t()]) :: state()
  defp refresh_or_close(state, _shop, []) do
    {:ok, closed} = close_shop(state, :sold_out)
    closed
  end

  defp refresh_or_close(%{game_state: gs} = state, shop, items) do
    new_shop = %{shop | items: items}
    Registry.put(gs.character_id, self(), new_shop)
    %{state | game_state: %{gs | state_context: new_shop}}
  end

  @spec build_sale_reports(shop(), [{non_neg_integer(), pos_integer()}], String.t()) ::
          [VendingSaleReport.t()]
  defp build_sale_reports(shop, removals, buyer_name) do
    Enum.map(removals, fn {index, amount} ->
      %ShopItem{nameid: nameid, price: price} =
        Enum.find(shop.items, &(&1.cart_index == index))

      %VendingSaleReport{
        index: index,
        nameid: nameid,
        amount: amount,
        zeny_gained: amount * price,
        buyer_name: buyer_name
      }
    end)
  end

  @spec notify_seller(pid(), [{non_neg_integer(), pos_integer()}], non_neg_integer()) :: :ok
  defp notify_seller(connection_pid, removals, new_zeny) do
    Enum.each(removals, fn {index, amount} ->
      MessageRouter.send_to(connection_pid, InventoryView.cart_item_removed(index, amount))
    end)

    StatusSync.send_param(connection_pid, StatusParams.zeny(), new_zeny)
  end

  @spec notify_buyer_added(pid(), Inventory.t(), [Inventory.change()]) :: :ok
  defp notify_buyer_added(connection_pid, inventory, changes) do
    Enum.each(changes, fn change ->
      Enum.each(affected_indices(change), fn index ->
        item = PlayerState.get_by_index(inventory, index)
        MessageRouter.send_to(connection_pid, InventoryView.item_added(item, index))
      end)
    end)
  end

  @spec affected_indices(Inventory.change()) :: [non_neg_integer()]
  defp affected_indices({:added, index, _item}), do: [index]
  defp affected_indices({:stacked, index, _total}), do: [index]

  defp affected_indices({:split, [{topped_index, _}, {new_index, _}]}),
    do: [topped_index, new_index]

  @spec ensure_cart_mounted(integer()) :: :ok | {:error, :no_cart}
  defp ensure_cart_mounted(char_id) do
    if StatusStorage.has_status?(:player, char_id, @push_cart_status) do
      :ok
    else
      {:error, :no_cart}
    end
  end

  @spec ensure_vending_learned(PlayerState.t()) ::
          {:ok, pos_integer()} | {:error, :skill_not_learned}
  defp ensure_vending_learned(%{stats: %{progression: %{learned_skills: learned}}}) do
    case Learned.learned_level(learned, @mc_vending_id) do
      level when level > 0 -> {:ok, level}
      _ -> {:error, :skill_not_learned}
    end
  end

  @spec broadcast_board(PlayerState.t(), struct()) :: :ok
  defp broadcast_board(%{map_name: map_name, x: x, y: y}, packet) do
    Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet, [])
  end
end
