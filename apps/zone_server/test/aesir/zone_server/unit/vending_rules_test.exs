defmodule Aesir.ZoneServer.Unit.VendingRulesTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Unit.Vending
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  test "supplied policy caps unit prices without rejecting free listings" do
    cart = %{
      0 => %InventoryItem{nameid: 501, amount: 5, identify: 1, bound: 0},
      1 => %InventoryItem{nameid: 502, amount: 2, identify: 1, bound: 0}
    }

    context = %{
      rules: %{
        max_price: 100,
        allow_over_max: true,
        tax: 500,
        tax_min: 100_000_000,
        show_buyer_name: true
      },
      seller_zeny: 0,
      eligibility: %{0 => :ok, 1 => :ok}
    }

    assert {:ok,
            [
              %ShopItem{cart_index: 1, amount: 2, price: 0},
              %ShopItem{cart_index: 0, amount: 3, price: 100}
            ]} = Vending.validate_open(cart, [{1, 2, 0}, {0, 3, 101}], 2, context)
  end

  test "listing count must be nonempty and fit the hard slot limit" do
    assert {:error, :no_items} = Vending.validate_open(%{}, [], 12)

    entries = Enum.map(0..12, &{&1, 1, 100})
    assert {:error, :too_many_slots} = Vending.validate_open(%{}, entries, 100)
  end

  test "one cart slot cannot be listed twice" do
    cart = %{0 => %InventoryItem{nameid: 501, amount: 5, identify: 1, bound: 0}}

    assert {:error, :duplicate_slot} = Vending.validate_open(cart, [{0, 3, 100}, {0, 3, 200}], 2)
  end

  test "an authorized bound listing can be bought without allowing later binding changes" do
    cart = %{0 => %InventoryItem{nameid: 501, amount: 5, identify: 1, bound: 1}}
    context = %{rules: Config.vending_rules(), seller_zeny: 0, eligibility: %{0 => :ok}}
    assert {:ok, shop} = Vending.validate_open(cart, [{0, 5, 100}], 1, context)

    assert {:ok, %{total_cost: 200, cart_removals: [{0, 2}]}} =
             Vending.compute_purchase(cart, shop, [{0, 2}])

    changed = %{0 => %{cart[0] | bound: 4}}
    assert {:error, :sold_out} = Vending.compute_purchase(changed, shop, [{0, 2}])
  end

  test "broken stock remains ineligible despite a permission grant" do
    cart = %{0 => %InventoryItem{nameid: 501, amount: 5, identify: 1, bound: 0, attribute: 1}}
    context = %{rules: Config.vending_rules(), seller_zeny: 0, eligibility: %{0 => :ok}}

    assert {:error, :item_broken} = Vending.validate_open(cart, [{0, 1, 100}], 1, context)
  end

  test "listing policy checks the prospective balance before any tax" do
    cart = %{0 => %InventoryItem{nameid: 501, amount: 2, identify: 1, bound: 0}}
    rules = %{Config.vending_rules() | allow_over_max: false}
    context = %{rules: rules, seller_zeny: 999_999_900, eligibility: %{0 => :ok}}

    assert {:error, :zeny_limit} = Vending.validate_open(cart, [{0, 2, 51}], 1, context)
    assert {:ok, [_]} = Vending.validate_open(cart, [{0, 2, 50}], 1, context)

    allowed = %{context | rules: %{rules | allow_over_max: true}}
    assert {:ok, [_]} = Vending.validate_open(cart, [{0, 2, 51}], 1, allowed)
  end

  test "tax applies to the basket threshold and truncates the final net credit" do
    for {gross, rate, minimum, expected} <- [
          {101, 0, 0, 101},
          {99, 500, 100, 99},
          {100, 500, 100, 95},
          {101, 500, 100, 95},
          {198, 500, 100, 188}
        ] do
      rules = %{Config.vending_rules() | tax: rate, tax_min: minimum}
      assert Vending.seller_credit(gross, rules) == expected
    end
  end

  test "title normalization enforces the byte limit without splitting UTF-8" do
    assert Vending.normalize_title(String.duplicate("a", 77) <> "éx") ==
             {:ok, String.duplicate("a", 77) <> "é"}

    assert Vending.normalize_title(String.duplicate("a", 78) <> "é") ==
             {:ok, String.duplicate("a", 78)}

    for invalid <- ["", "bad\nshop", "bad" <> <<0>>, <<255>>] do
      assert {:error, :invalid_title} = Vending.normalize_title(invalid)
    end
  end

  test "duplicate purchase lines share one cumulative stock allowance" do
    cart = %{
      0 => %InventoryItem{nameid: 501, amount: 5, identify: 1, bound: 0},
      1 => %InventoryItem{nameid: 502, amount: 1, identify: 1, bound: 0}
    }

    assert {:ok, shop} = Vending.validate_open(cart, [{0, 5, 100}, {1, 1, 50}], 2)

    assert {:error, :insufficient_stock} =
             Vending.compute_purchase(cart, shop, [{0, 3}, {0, 3}])

    assert {:ok, %{total_cost: 300, cart_removals: [{0, 3}]}} =
             Vending.compute_purchase(cart, shop, [{0, 1}, {0, 2}])
  end

  test "checkout rejects an empty or oversized line list before coalescing" do
    cart = %{0 => %InventoryItem{nameid: 501, amount: 5, identify: 1, bound: 0}}
    assert {:ok, shop} = Vending.validate_open(cart, [{0, 5, 100}], 1)

    for lines <- [[], [{0, 1}, {0, 1}], [{0, 0}]] do
      assert {:error, :invalid_amount} = Vending.compute_purchase(cart, shop, lines)
    end
  end
end
