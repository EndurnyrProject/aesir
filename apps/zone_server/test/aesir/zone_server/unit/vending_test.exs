defmodule Aesir.ZoneServer.Unit.VendingTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.Vending`.

  No DB, no sockets: cart maps are built with real `%InventoryItem{}` structs
  via `PlayerState.from_list/1`, mirroring the cart core tests.
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Vending
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  @red_potion 501
  @sword 1101

  defp item(attrs) do
    base = %{
      id: System.unique_integer([:positive]),
      char_id: 1,
      nameid: @red_potion,
      amount: 1,
      equip: 0,
      identify: 1,
      refine: 0,
      attribute: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      random_options: %{},
      enchant_grade: 0
    }

    struct(InventoryItem, Map.merge(base, Map.new(attrs)))
  end

  defp cart(items), do: PlayerState.from_list(items)

  describe "validate_open/3" do
    test "accepts a valid request and resolves nameid from the cart slot" do
      c = cart([item(nameid: @red_potion, amount: 10), item(nameid: @sword, amount: 1)])

      assert {:ok, items} = Vending.validate_open(c, [{0, 5, 1_000}, {1, 1, 50_000}], 12)

      assert [
               %ShopItem{cart_index: 0, nameid: @red_potion, amount: 5, price: 1_000},
               %ShopItem{cart_index: 1, nameid: @sword, amount: 1, price: 50_000}
             ] = items
    end

    test "rejects more lines than max_slots" do
      c = cart([item(nameid: @red_potion, amount: 10)])

      assert {:error, :too_many_slots} =
               Vending.validate_open(c, [{0, 1, 100}, {0, 1, 100}], 1)
    end

    test "rejects a price of 0" do
      c = cart([item(nameid: @red_potion, amount: 10)])

      assert {:error, :invalid_price} = Vending.validate_open(c, [{0, 1, 0}], 12)
    end

    test "rejects a price over the cap" do
      c = cart([item(nameid: @red_potion, amount: 10)])

      assert {:error, :invalid_price} = Vending.validate_open(c, [{0, 1, 100_000_000}], 12)
    end

    test "rejects a line whose cart slot lacks the amount" do
      c = cart([item(nameid: @red_potion, amount: 3)])

      assert {:error, :insufficient_stock} = Vending.validate_open(c, [{0, 5, 100}], 12)
    end

    test "rejects an unidentified cart item" do
      c = cart([item(nameid: @sword, identify: 0)])

      assert {:error, :item_unidentified} = Vending.validate_open(c, [{0, 1, 50_000}], 12)
    end

    test "rejects the entire shop when one selected cart item is unidentified" do
      c = cart([item(nameid: @red_potion, amount: 5), item(nameid: @sword, identify: 0)])

      assert {:error, :item_unidentified} =
               Vending.validate_open(c, [{0, 5, 100}, {1, 1, 50_000}], 12)
    end

    test "rejects bound cart items" do
      for bound <- [1, 4] do
        c = cart([item(nameid: @red_potion, amount: 5, bound: bound)])

        assert {:error, :item_bound} = Vending.validate_open(c, [{0, 5, 100}], 12)
      end
    end

    test "rejects a line referencing an empty cart slot" do
      c = cart([item(nameid: @red_potion, amount: 3)])

      assert {:error, :item_not_in_cart} = Vending.validate_open(c, [{9, 1, 100}], 12)
    end
  end

  describe "build_snapshot/2" do
    test "merges the listing with live cart display attrs" do
      c = cart([item(nameid: @sword, amount: 1, refine: 7, identify: 1)])
      {:ok, shop} = Vending.validate_open(c, [{0, 1, 50_000}], 12)

      assert [
               %{index: 0, nameid: @sword, amount: 1, price: 50_000, refine: 7, identify: 1}
             ] = Vending.build_snapshot(c, shop)
    end

    test "drops lines whose cart slot is gone" do
      c = cart([item(nameid: @red_potion, amount: 5)])
      {:ok, shop} = Vending.validate_open(c, [{0, 5, 100}], 12)

      assert Vending.build_snapshot(%{}, shop) == []
    end
  end

  describe "compute_purchase/3" do
    setup do
      c = cart([item(nameid: @red_potion, amount: 10)])
      {:ok, shop} = Vending.validate_open(c, [{0, 10, 1_000}], 12)
      %{cart: c, shop: shop}
    end

    test "computes total cost and deltas for a partial-amount buy", %{cart: c, shop: shop} do
      assert {:ok, result} = Vending.compute_purchase(c, shop, [{0, 3}])

      assert result.total_cost == 3_000
      assert result.cart_removals == [{0, 3}]
      assert [{%InventoryItem{nameid: @red_potion}, 3}] = result.inventory_adds
    end

    test "returns :sold_out when the live cart no longer holds enough", %{shop: shop} do
      live = cart([item(nameid: @red_potion, amount: 2)])

      assert {:error, :sold_out} = Vending.compute_purchase(live, shop, [{0, 3}])
    end

    test "returns :sold_out when the live cart slot is gone", %{shop: shop} do
      assert {:error, :sold_out} = Vending.compute_purchase(%{}, shop, [{0, 1}])
    end

    test "returns :sold_out when the live cart item becomes bound", %{shop: shop} do
      live = cart([item(nameid: @red_potion, amount: 10, bound: 1)])

      assert {:error, :sold_out} = Vending.compute_purchase(live, shop, [{0, 3}])
    end

    test "returns :bad_line for an index not on the shop", %{cart: c, shop: shop} do
      assert {:error, :bad_line} = Vending.compute_purchase(c, shop, [{5, 1}])
    end

    test "returns :bad_line when buying over the listed amount", %{cart: c} do
      {:ok, shop} = Vending.validate_open(c, [{0, 4, 1_000}], 12)

      assert {:error, :bad_line} = Vending.compute_purchase(c, shop, [{0, 5}])
    end
  end
end
