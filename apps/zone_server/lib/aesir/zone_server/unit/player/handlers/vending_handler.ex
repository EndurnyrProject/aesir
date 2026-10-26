defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler do
  @moduledoc """
  Public session entry points and vending purchase settlement.

  `VendingShopHandler` owns paid setup, opening, browsing and closure; these
  entry points retain the established session API.

  A checkout validates live stock and commits both participants' durable item
  and zeny changes in one database transaction, while the other participant's
  session is parked in a synchronous call so its snapshot cannot change.
  Synchronous calls only ever go from the lower character id to the higher one,
  so concurrent checkouts can never wait on each other in a cycle:

    * buyer id < seller id: the buyer calls the seller, which settles and
      replies with the buyer's delta (`handle_purchase/4`);
    * buyer id > seller id: the buyer casts an invitation, and the seller calls
      the buyer with its own snapshot; the buyer settles and replies with the
      seller's outcome (`handle_purchase_invite/3`, `handle_settle/3`).

  Either way each session applies only its own outcome. The buyer remembers its
  latest checkout request, so a replay returns the cached result without
  settling again, and an older request ID never executes. Unsold stock stays in
  the cart.
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingPurchaseRequest
  alias Aesir.Net.VendingPurchaseResult
  alias Aesir.Net.VendingSaleReport
  alias Aesir.Repo
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingShopHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending
  alias Aesir.ZoneServer.Unit.Vending.Permissions
  alias Aesir.ZoneServer.Unit.Vending.Registry
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  @purchase_codes %{
    not_open: :VEND_PURCHASE_NOT_OPEN,
    shop_changed: :VEND_PURCHASE_SHOP_CHANGED,
    price_changed: :VEND_PURCHASE_PRICE_CHANGED,
    insufficient_stock: :VEND_PURCHASE_INSUFFICIENT_STOCK,
    sold_out: :VEND_PURCHASE_INSUFFICIENT_STOCK,
    bad_line: :VEND_PURCHASE_INVALID_LINE,
    invalid_amount: :VEND_PURCHASE_INVALID_AMOUNT,
    not_enough_zeny: :VEND_PURCHASE_NOT_ENOUGH_ZENY,
    overweight: :VEND_PURCHASE_OVERWEIGHT,
    no_slots: :VEND_PURCHASE_NO_SLOTS,
    stack_limit: :VEND_PURCHASE_STACK_LIMIT,
    seller_zeny_limit: :VEND_PURCHASE_SELLER_ZENY_LIMIT,
    forbidden: :VEND_PURCHASE_FORBIDDEN,
    out_of_range: :VEND_PURCHASE_OUT_OF_RANGE,
    wrong_map: :VEND_PURCHASE_WRONG_MAP,
    self_purchase: :VEND_PURCHASE_SELF_PURCHASE,
    invalid_request: :VEND_PURCHASE_INVALID_REQUEST,
    stale_request: :VEND_PURCHASE_STALE_REQUEST,
    invalid_state: :VEND_PURCHASE_INVALID_STATE,
    persistence_failed: :VEND_PURCHASE_PERSISTENCE_FAILED
  }

  @doc "Publishes a preparation grant after the normal skill has paid its cost."
  @spec prepare_setup(state(), map()) :: {:ok, state()} | {:error, atom()}
  defdelegate prepare_setup(state, offer), to: VendingShopHandler

  @doc "Submits listings against the client's exact paid setup grant."
  @spec handle_open(state(), Aesir.Net.VendingOpenRequest.t()) :: {:noreply, state()}
  defdelegate handle_open(state, request), to: VendingShopHandler

  @doc "Cancels the owned preparation without restoring its paid skill cost."
  @spec cancel_setup(state(), atom()) :: state()
  defdelegate cancel_setup(state, reason), to: VendingShopHandler

  @doc "Closes only the setup or shop identified by the client's request."
  @spec handle_close(state(), Aesir.Net.VendingCloseRequest.t()) :: {:noreply, state()}
  defdelegate handle_close(state, request), to: VendingShopHandler

  @typedoc "The live shop carried in `PlayerState.vending_shop` and the registry."
  @type shop :: %{
          shop_id: String.t(),
          title: String.t(),
          owner_char_id: integer(),
          items: [ShopItem.t()],
          total_earned: non_neg_integer(),
          sale_sequence: non_neg_integer()
        }

  @typedoc """
  What the buyer session reconciles after a committed checkout: the persisted
  buyer inventory map (rows carry their real DB ids), the per-add change
  descriptors (one `ItemAdded` per touched slot), the zeny already debited, and
  the shop the checkout settled against.
  """
  @type buyer_delta :: %{
          inventory: Inventory.t(),
          item_changes: [Inventory.change()],
          zeny_spent: non_neg_integer(),
          shop_id: String.t()
        }

  @typedoc """
  What the seller session applies after a committed checkout: the persisted
  cart, the net zeny balance, the updated shop (remaining listings, earnings and
  sale sequence), the per-line cart removals and the sale reports to deliver.
  """
  @type seller_outcome :: %{
          cart: Cart.t(),
          zeny: non_neg_integer(),
          shop: shop(),
          removals: [{non_neg_integer(), pos_integer()}],
          reports: [VendingSaleReport.t()]
        }

  @type state :: SessionState.t()

  @doc "Opens listings from a server-held paid preparation grant."
  @spec open_shop(state(), String.t(), [Vending.entry()]) :: {:ok, state()} | {:error, atom()}
  defdelegate open_shop(state, title, entries), to: VendingShopHandler

  @doc "Closes the owned shop or releases preparation during lifecycle teardown."
  @spec close_shop(state(), atom()) :: {:ok, state()}
  defdelegate close_shop(state, reason), to: VendingShopHandler

  @doc "Replies to a browse request with explicit snapshot or refusal."
  @spec handle_list(state(), Aesir.Net.VendingListRequest.t()) :: {:noreply, state()}
  defdelegate handle_list(state, request), to: VendingShopHandler

  @doc "Publishes current owned-shop state without a client request."
  @spec publish_owner_snapshot(state()) :: state()
  defdelegate publish_owner_snapshot(state), to: VendingShopHandler

  @doc "Whether preparation or an open shop holds the player against other actions."
  @spec locked?(state()) :: boolean()
  defdelegate locked?(state), to: VendingShopHandler

  @doc "Whether cart transfers are refused: in preparation and while vending."
  @spec cart_locked?(state()) :: boolean()
  defdelegate cart_locked?(state), to: VendingShopHandler, as: :locked?

  @doc "Closes or keeps the open shop for a relocation, before the player leaves."
  @spec reconcile_relocation(state(), String.t(), non_neg_integer(), non_neg_integer()) ::
          state()
  defdelegate reconcile_relocation(state, map_name, x, y), to: VendingShopHandler

  @doc "Reads a live vending snapshot without calling its owning session."
  @spec build_list(integer()) :: {:ok, VendingList.t()} | :error
  defdelegate build_list(vendor_unit_id), to: VendingShopHandler

  @doc """
  Starts a client checkout in the buyer session and always answers it with a
  correlated `VendingPurchaseResult`, except for a duplicate of the checkout
  still in flight, whose own result is still to come.

  The same request ID with the same payload resends the cached result without
  settling again. A reused ID with another payload, or an ID older than the
  latest, is stale; a new ID while a checkout is in flight is refused.
  """
  @spec handle_purchase_request(state(), VendingPurchaseRequest.t()) :: {:noreply, state()}
  def handle_purchase_request(%SessionState{} = state, %VendingPurchaseRequest{} = request) do
    payload = {request.vendor_unit_id, request.shop_id, request.items}

    case replay(state.vending_purchase, request.request_id, payload) do
      :new ->
        {:noreply, start_purchase(state, request.request_id, payload)}

      :pending ->
        {:noreply, state}

      {:cached, result} ->
        MessageRouter.send_to(state.connection_pid, result)
        {:noreply, state}

      {:error, reason} ->
        MessageRouter.send_to(state.connection_pid, result(request.request_id, payload, reason))
        {:noreply, state}
    end
  end

  defp replay(_latest, 0, _payload), do: {:error, :invalid_request}
  defp replay(nil, _id, _payload), do: :new
  defp replay(%{request_id: id, payload: payload, result: nil}, id, payload), do: :pending
  defp replay(%{request_id: id, payload: payload, result: done}, id, payload), do: {:cached, done}
  defp replay(%{request_id: latest}, id, _payload) when id <= latest, do: {:error, :stale_request}
  defp replay(%{result: nil}, _id, _payload), do: {:error, :invalid_state}
  defp replay(_latest, _id, _payload), do: :new

  defp start_purchase(%{game_state: gs} = state, request_id, payload) do
    {vendor_id, shop_id, rows} = payload
    pending = %{request_id: request_id, payload: payload, result: nil, monitor: nil}
    state = %{state | vending_purchase: pending}

    with :ok <- check_identity(vendor_id, shop_id),
         :ok <- reject_self_purchase(vendor_id, gs.character_id),
         {:ok, seller_pid} <- seller_pid(vendor_id) do
      if gs.character_id < vendor_id do
        finish_purchase(state, PlayerSession.vending_purchase(seller_pid, gs, shop_id, rows))
      else
        monitor = Process.monitor(seller_pid)
        :ok = PlayerSession.vending_purchase_invite(seller_pid, self(), request_id)
        %{state | vending_purchase: %{pending | monitor: monitor}}
      end
    else
      {:error, reason} -> finish_purchase(state, {:error, reason})
    end
  end

  defp check_identity(vendor_id, shop_id) when vendor_id > 0 and shop_id != "", do: :ok
  defp check_identity(_vendor_id, _shop_id), do: {:error, :invalid_request}

  # Buying from oneself would also resolve the seller to self() and deadlock.
  defp reject_self_purchase(char_id, char_id), do: {:error, :self_purchase}
  defp reject_self_purchase(_vendor_id, _char_id), do: :ok

  defp seller_pid(vendor_id) do
    case UnitRegistry.get_player_pid(vendor_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, _missing} -> {:error, :not_open}
    end
  end

  # Settles the in-flight checkout: applies a committed delta, replies to the
  # client and caches the result against its request ID.
  defp finish_purchase(%{vending_purchase: pending} = state, outcome) do
    {state, packet} =
      case outcome do
        {:ok, delta} ->
          {:ok, applied} = apply_purchase_as_buyer(state, delta)

          packet = %{
            result(pending.request_id, pending.payload, :ok)
            | shop_id: delta.shop_id,
              total_charged: delta.zeny_spent
          }

          {StateCommit.commit(applied, applied.game_state), packet}

        {:error, reason} ->
          Logger.debug(
            "Vending purchase #{pending.request_id} by #{state.game_state.character_id} " <>
              "failed: #{inspect(reason)}"
          )

          {state, result(pending.request_id, pending.payload, reason)}
      end

    MessageRouter.send_to(state.connection_pid, packet)
    %{state | vending_purchase: %{pending | result: packet, monitor: nil}}
  end

  defp result(request_id, {vendor_id, shop_id, _rows}, reason) do
    %VendingPurchaseResult{
      request_id: request_id,
      vendor_unit_id: vendor_id,
      shop_id: shop_id,
      result: result_code(reason)
    }
  end

  defp result_code(:ok), do: :VEND_PURCHASE_OK
  defp result_code(reason), do: Map.get(@purchase_codes, reason, :VEND_PURCHASE_INTERNAL_ERROR)

  @doc """
  Seller side of a lower-id buyer's checkout: settles against this session's
  live shop and the parked buyer's snapshot, applies the seller outcome here and
  replies with the buyer's delta.
  """
  @spec handle_purchase(state(), PlayerState.t(), String.t(), [VendingBuy.t()]) ::
          {:reply, {:ok, buyer_delta()} | {:error, atom()}, state()}
  def handle_purchase(%SessionState{} = seller_state, %PlayerState{} = buyer_gs, shop_id, rows) do
    case settle(seller_state.game_state, buyer_gs, shop_id, rows) do
      {:ok, outcome, buyer_delta} ->
        {:reply, {:ok, buyer_delta}, apply_seller_outcome(seller_state, outcome)}

      {:error, _reason} = error ->
        {:reply, error, seller_state}
    end
  end

  @doc """
  Seller side of a higher-id buyer's checkout: parks in a call on the buyer
  with this session's snapshot and applies the seller outcome it returns.
  """
  @spec handle_purchase_invite(state(), pid(), pos_integer()) :: {:noreply, state()}
  def handle_purchase_invite(%SessionState{} = seller_state, buyer_pid, request_id) do
    case PlayerSession.vending_settle(buyer_pid, request_id, seller_state.game_state) do
      {:ok, outcome} -> {:noreply, apply_seller_outcome(seller_state, outcome)}
      {:error, _reason} -> {:noreply, seller_state}
    end
  end

  @doc """
  Buyer side of its invited checkout: settles with the parked seller's snapshot,
  finishes the checkout here and replies with the seller's outcome. A call for
  any other request, or from another vendor, is stale and settles nothing.
  """
  @spec handle_settle(state(), pos_integer(), PlayerState.t()) ::
          {:reply, {:ok, seller_outcome()} | {:error, atom()}, state()}
  def handle_settle(
        %SessionState{
          vending_purchase: %{
            request_id: id,
            result: nil,
            monitor: monitor,
            payload: {vendor_id, shop_id, rows}
          }
        } = state,
        id,
        %PlayerState{character_id: vendor_id} = seller_gs
      )
      when is_reference(monitor) do
    Process.demonitor(monitor, [:flush])

    case settle(seller_gs, state.game_state, shop_id, rows) do
      {:ok, outcome, buyer_delta} ->
        {:reply, {:ok, outcome}, finish_purchase(state, {:ok, buyer_delta})}

      {:error, _reason} = error ->
        {:reply, error, finish_purchase(state, error)}
    end
  end

  def handle_settle(state, _request_id, _seller_gs), do: {:reply, {:error, :stale_request}, state}

  @doc "Fails the invited checkout whose seller session ended before settling it."
  @spec handle_seller_down(state()) :: {:noreply, state()}
  def handle_seller_down(state), do: {:noreply, finish_purchase(state, {:error, :not_open})}

  @doc """
  Validates and commits one checkout between two frozen snapshots.

  Checks, in order: the seller is vending (`:not_open`) the requested shop
  (`:shop_changed`), the buyer is on its map (`:wrong_map`) within view range
  (`:out_of_range`), both may trade (`:forbidden`), then every line through
  `Vending.compute_purchase/4`. The buyer is debited the pre-tax total and the
  seller credited the basket's net amount, together with the cart removals and
  inventory adds, in one transaction (`:persistence_failed` rolls back all).
  Each line reports its own net amount, the purchase's shared sale sequence and
  the shop's cumulative net earnings. Runs in whichever session is not parked;
  neither session's state is touched here.
  """
  @spec settle(PlayerState.t(), PlayerState.t(), String.t(), [VendingBuy.t()]) ::
          {:ok, seller_outcome(), buyer_delta()} | {:error, atom()}
  def settle(%PlayerState{} = seller_gs, %PlayerState{} = buyer_gs, shop_id, rows) do
    lines = Enum.map(rows, &{&1.index, &1.amount, &1.expected_unit_price})
    rules = Config.vending_rules()

    context = %{
      buyer_zeny: buyer_gs.zeny,
      seller_zeny: seller_gs.zeny,
      weight_room: Inventory.weight_room(buyer_gs.inventory, buyer_gs.stats),
      inventory: buyer_gs.inventory
    }

    with {:ok, shop} <- fetch_shop(seller_gs),
         :ok <- check_shop(shop, shop_id),
         :ok <- check_location(buyer_gs, seller_gs),
         :ok <- check_interaction(buyer_gs, seller_gs),
         {:ok, plan} <- Vending.compute_purchase(seller_gs.cart, shop.items, lines, context),
         credit = Vending.seller_credit(plan.total_cost, rules),
         {:ok, cart, inventory, changes} <- transact_purchase(seller_gs, buyer_gs, plan, credit) do
      report = %VendingSaleReport{
        shop_id: shop.shop_id,
        sale_sequence: shop.sale_sequence + 1,
        total_earned: shop.total_earned + credit,
        buyer_name: if(rules.show_buyer_name, do: buyer_gs.character_name, else: "")
      }

      outcome = %{
        cart: cart,
        zeny: seller_gs.zeny + credit,
        shop: %{
          shop
          | items: reduce_shop_items(shop.items, plan.cart_removals),
            sale_sequence: report.sale_sequence,
            total_earned: report.total_earned
        },
        removals: plan.cart_removals,
        reports: Enum.map(plan.cart_removals, &sale_report(&1, shop.items, report, rules))
      }

      {:ok, outcome,
       %{
         inventory: inventory,
         item_changes: changes,
         zeny_spent: plan.total_cost,
         shop_id: shop.shop_id
       }}
    end
  end

  defp fetch_shop(%{vending_shop: %{shop_id: _, items: _} = shop}), do: {:ok, shop}

  defp fetch_shop(_seller_gs), do: {:error, :not_open}

  defp check_shop(%{shop_id: shop_id}, shop_id), do: :ok
  defp check_shop(_shop, _shop_id), do: {:error, :shop_changed}

  defp check_location(%{map_name: map} = buyer, %{map_name: map} = seller) do
    if Geometry.chebyshev_distance(buyer.x, buyer.y, seller.x, seller.y) <= Config.view_range(),
      do: :ok,
      else: {:error, :out_of_range}
  end

  defp check_location(_buyer, _seller), do: {:error, :wrong_map}

  defp check_interaction(buyer_gs, seller_gs) do
    if Permissions.can_trade?(PortalAccess.trade_permissions(buyer_gs)) and
         Permissions.can_trade?(PortalAccess.trade_permissions(seller_gs)),
       do: :ok,
       else: {:error, :forbidden}
  end

  # Each line reports its own amount net of tax, taxed on that line alone.
  defp sale_report({index, amount}, items, report, rules) do
    %ShopItem{nameid: nameid, price: price} = Enum.find(items, &(&1.cart_index == index))

    %{
      report
      | index: index,
        nameid: nameid,
        amount: amount,
        zeny_gained: Vending.seller_credit(amount * price, rules)
    }
  end

  @spec reduce_shop_items([ShopItem.t()], [{non_neg_integer(), pos_integer()}]) ::
          [ShopItem.t()]
  defp reduce_shop_items(items, removals) do
    sold =
      Enum.reduce(removals, %{}, fn {index, amount}, acc ->
        Map.update(acc, index, amount, &(&1 + amount))
      end)

    items
    |> Enum.map(fn %ShopItem{cart_index: index, amount: amount} = item ->
      %{item | amount: amount - Map.get(sold, index, 0)}
    end)
    |> Enum.reject(fn %ShopItem{amount: amount} -> amount <= 0 end)
  end

  defp transact_purchase(seller_gs, buyer_gs, plan, credit) do
    Repo.transact(fn ->
      with {:ok, cart} <-
             apply_cart_removals(seller_gs.character_id, seller_gs.cart, plan.cart_removals),
           {:ok, _} <-
             CharacterPersistence.update_character(seller_gs.character_id, %{
               zeny: seller_gs.zeny + credit
             }),
           {:ok, inventory, changes} <-
             apply_buyer_adds(buyer_gs.character_id, buyer_gs.inventory, plan.inventory_adds),
           {:ok, _} <-
             CharacterPersistence.update_character(buyer_gs.character_id, %{
               zeny: buyer_gs.zeny - plan.total_cost
             }) do
        {:ok, {cart, inventory, changes}}
      end
    end)
    |> case do
      {:ok, {cart, inventory, changes}} ->
        {:ok, cart, inventory, changes}

      {:error, reason} ->
        Logger.error(
          "Vending purchase from #{seller_gs.character_id} by #{buyer_gs.character_id} " <>
            "rolled back: #{inspect(reason)}"
        )

        {:error, :persistence_failed}
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
             Inventory.add_item(current, item_def, source, amount, :infinity),
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

  # Runs in the seller session: adopts the committed cart and zeny, notifies its
  # client (cart removals, zeny, then the sale reports) and refreshes the shop,
  # closing it once nothing remains listed.
  @spec apply_seller_outcome(state(), seller_outcome()) :: state()
  defp apply_seller_outcome(%{game_state: gs} = state, outcome) do
    notify_seller(state.connection_pid, outcome.removals, outcome.zeny)
    Enum.each(outcome.reports, &MessageRouter.send_to(state.connection_pid, &1))

    state = %{
      state
      | game_state: %{gs | cart: outcome.cart, zeny: outcome.zeny, vending_shop: outcome.shop}
    }

    state = refresh_or_close(state, outcome.shop)
    StateCommit.commit(state, state.game_state)
  end

  defp refresh_or_close(state, %{items: []}) do
    {:ok, closed} = close_shop(state, :sold_out)
    closed
  end

  defp refresh_or_close(%{game_state: gs} = state, shop) do
    Registry.put(gs.character_id, self(), shop)
    state
  end

  @doc """
  Applies a committed `buyer_delta` to the buyer's in-memory session.

  The DB rows (inventory inserts/stacks + zeny debit) were already committed by
  the settling transaction, so this only reconciles in-memory state and pushes
  the buyer's client packets: it adopts the persisted inventory map, debits the
  spent zeny, emits one `ItemAdded` per touched slot, and a zeny `ParamChange`.
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
      Enum.each(ItemContainer.affected_indices(change), fn index ->
        item = PlayerState.get_by_index(inventory, index)
        MessageRouter.send_to(connection_pid, InventoryView.item_added(item, index))
      end)
    end)
  end
end
