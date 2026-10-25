defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingSettlementTest do
  @moduledoc """
  The checkout's per-line check order (`Vending.compute_purchase/4`) and the
  buyer session's request bookkeeping: replay of the latest result, stale and
  concurrent requests, and settlement of an invited checkout. Committed
  transfers are covered by `VendingBuyTest` and the settlement integrations.
  """

  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingPurchaseRequest
  alias Aesir.Net.VendingPurchaseResult
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Vending
  alias Aesir.ZoneServer.Unit.Vending.ShopItem
  alias Aesir.ZoneServer.Unit.Zeny

  setup :setup_ets_tables

  @potion 501
  @knife 1201

  describe "compute_purchase/4 check order" do
    setup do
      cart = %{0 => %InventoryItem{nameid: @potion, amount: 5, identify: 1, bound: 0}}
      shop = [%ShopItem{cart_index: 0, nameid: @potion, amount: 5, price: 100}]
      context = %{buyer_zeny: 10_000, seller_zeny: 0, weight_room: :infinity, inventory: %{}}
      %{cart: cart, shop: shop, context: context}
    end

    test "funds are checked before the listing's quantity", %{cart: cart, shop: shop} = ctx do
      context = %{ctx.context | buyer_zeny: 300}

      assert {:error, :not_enough_zeny} =
               Vending.compute_purchase(cart, shop, [{0, 6, 100}], context)
    end

    test "the seller's pre-tax balance is capped before weight",
         %{cart: cart, shop: shop} = ctx do
      context = %{ctx.context | seller_zeny: Zeny.max_zeny() - 99, weight_room: 0}

      assert {:error, :seller_zeny_limit} =
               Vending.compute_purchase(cart, shop, [{0, 1, 100}], context)
    end

    test "weight is checked before stock", %{cart: cart, shop: shop} = ctx do
      context = %{ctx.context | weight_room: 0}

      assert {:error, :overweight} = Vending.compute_purchase(cart, shop, [{0, 6, 100}], context)
    end

    test "a changed quote refuses the line", %{cart: cart, shop: shop, context: context} do
      assert {:error, :price_changed} =
               Vending.compute_purchase(cart, shop, [{0, 1, 99}], context)
    end

    test "the live cart clamps the listing across duplicate lines", %{shop: shop} = ctx do
      cart = %{0 => %InventoryItem{nameid: @potion, amount: 3, identify: 1, bound: 0}}
      shop = shop ++ [%ShopItem{cart_index: 1, nameid: 502, amount: 1, price: 1}]

      assert {:error, :sold_out} =
               Vending.compute_purchase(cart, shop, [{0, 2, 100}, {0, 2, 100}], ctx.context)
    end

    test "a full inventory has no slot for a new stack", %{cart: cart, shop: shop} = ctx do
      full = Map.new(0..(Inventory.capacity() - 1), &{&1, knife()})

      assert {:error, :no_slots} =
               Vending.compute_purchase(cart, shop, [{0, 1, 100}], %{
                 ctx.context
                 | inventory: full
               })
    end

    test "a held stack may not pass the stack cap", %{cart: cart, shop: shop} = ctx do
      held = %{0 => %InventoryItem{nameid: @potion, amount: 29_999, identify: 1, bound: 0}}

      assert {:error, :stack_limit} =
               Vending.compute_purchase(cart, shop, [{0, 2, 100}], %{
                 ctx.context
                 | inventory: held
               })
    end

    test "duplicate lines stay separate removals and adds", %{cart: cart, shop: shop} = ctx do
      shop = shop ++ [%ShopItem{cart_index: 1, nameid: 502, amount: 1, price: 1}]

      assert {:ok, %{total_cost: 300, cart_removals: [{0, 1}, {0, 2}], inventory_adds: adds}} =
               Vending.compute_purchase(cart, shop, [{0, 1, 100}, {0, 2, 100}], ctx.context)

      assert [{%InventoryItem{nameid: @potion}, 1}, {%InventoryItem{nameid: @potion}, 2}] = adds
    end
  end

  describe "handle_purchase_request/2 request bookkeeping" do
    test "the latest result is cached and resent for an identical replay" do
      state = buyer_state()

      {:noreply, state} = VendingHandler.handle_purchase_request(state, request(5))
      first = assert_result(5, :VEND_PURCHASE_NOT_OPEN)

      {:noreply, ^state} = VendingHandler.handle_purchase_request(state, request(5))
      assert ^first = assert_result(5, :VEND_PURCHASE_NOT_OPEN)
    end

    test "a reused ID with another payload or an older ID is stale" do
      {:noreply, state} = VendingHandler.handle_purchase_request(buyer_state(), request(5))
      assert_result(5, :VEND_PURCHASE_NOT_OPEN)

      {:noreply, ^state} = VendingHandler.handle_purchase_request(state, request(5, amount: 2))
      assert_result(5, :VEND_PURCHASE_STALE_REQUEST)

      {:noreply, ^state} = VendingHandler.handle_purchase_request(state, request(4))
      assert_result(4, :VEND_PURCHASE_STALE_REQUEST)
    end

    test "missing request identities are refused" do
      {:noreply, state} = VendingHandler.handle_purchase_request(buyer_state(), request(0))
      assert_result(0, :VEND_PURCHASE_INVALID_REQUEST)
      assert state.vending_purchase == nil

      {:noreply, state} = VendingHandler.handle_purchase_request(state, request(1, shop_id: ""))
      assert_result(1, :VEND_PURCHASE_INVALID_REQUEST)
      assert %{request_id: 1} = state.vending_purchase
    end

    test "an in-flight checkout ignores its duplicate and refuses a new request" do
      state = in_flight(buyer_state(), 7)

      {:noreply, ^state} = VendingHandler.handle_purchase_request(state, request(7))
      refute_received {:send, _channel, _body}

      {:noreply, ^state} = VendingHandler.handle_purchase_request(state, request(8))
      assert_result(8, :VEND_PURCHASE_INVALID_STATE)
    end
  end

  describe "invited checkout" do
    test "a settle call for another request or vendor settles nothing" do
      state = in_flight(buyer_state(), 7)

      assert {:reply, {:error, :stale_request}, ^state} =
               VendingHandler.handle_settle(state, 8, seller_gs(2))

      assert {:reply, {:error, :stale_request}, ^state} =
               VendingHandler.handle_settle(state, 7, seller_gs(3))
    end

    test "a seller that ends before settling fails the checkout" do
      state = in_flight(buyer_state(), 7)

      {:noreply, state} = VendingHandler.handle_seller_down(state)

      result = assert_result(7, :VEND_PURCHASE_NOT_OPEN)
      assert %{result: ^result, monitor: nil} = state.vending_purchase
    end
  end

  defp knife, do: %InventoryItem{nameid: @knife, amount: 1, identify: 1, bound: 0}

  defp buyer_state do
    %SessionState{game_state: PlayerState.new(character(10, "Buyer")), connection_pid: self()}
  end

  defp seller_gs(id), do: PlayerState.new(character(id, "Seller"))

  defp in_flight(state, request_id) do
    %{
      state
      | vending_purchase: %{
          request_id: request_id,
          payload: payload(request(request_id)),
          result: nil,
          monitor: make_ref()
        }
    }
  end

  defp request(request_id, opts \\ []) do
    %VendingPurchaseRequest{
      request_id: request_id,
      vendor_unit_id: 2,
      shop_id: Keyword.get(opts, :shop_id, "shop"),
      items: [
        %VendingBuy{index: 0, amount: Keyword.get(opts, :amount, 1), expected_unit_price: 100}
      ]
    }
  end

  defp payload(request), do: {request.vendor_unit_id, request.shop_id, request.items}

  defp assert_result(request_id, code) do
    assert_received {:send, _channel,
                     {:vending_purchase_result,
                      %VendingPurchaseResult{request_id: ^request_id, result: ^code} = result}}

    result
  end

  defp character(id, name) do
    %Character{
      id: id,
      account_id: id * 100,
      name: name,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 5,
      base_level: 50,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end
end
