defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingBuyTest do
  @moduledoc """
  DataCase coverage for the seller-authoritative cross-player vending buy
  (`VendingHandler.handle_purchase/4` + `apply_purchase_as_buyer/2`): the four-row
  atomic transfer, its failure modes, auto-close on sell-out, and the
  duplicate-line over-sell guard.
  """
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingSaleReport
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Cart.Persistence, as: CartPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Vending.Registry
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  @potion 501
  @orange 502

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(InventoryPersistence)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)
    :ok
  end

  setup do
    seller = insert_character("Merchy", 1_000_000)
    buyer = insert_character("Buyer", 1_000)
    %{seller: seller, buyer: buyer}
  end

  describe "handle_purchase/4" do
    test "transfers cart -> buyer inventory and zeny both ways in one transaction", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      assert {:ok, new_state, buyer_delta, [report]} =
               purchase(seller_state, buyer, %{}, 1_000, stats(buyer), "Buyer", [
                 {index, 4}
               ])

      # Seller side: cart row reduced, characters.zeny credited.
      assert [%CartItem{nameid: @potion, amount: 6}] = CartPersistence.load_cart(seller.id)
      assert reload_zeny(seller.id) == 1_000_000 + 400
      assert %{^index => %InventoryItem{amount: 6}} = new_state.game_state.cart
      assert new_state.game_state.zeny == 1_000_000 + 400

      # Buyer side: inventory row inserted, characters.zeny debited.
      assert [%InventoryItem{nameid: @potion, amount: 4}] =
               InventoryPersistence.load_inventory(buyer.id)

      assert reload_zeny(buyer.id) == 1_000 - 400
      assert buyer_delta.zeny_spent == 400
      assert [%InventoryItem{nameid: @potion, amount: 4}] = Map.values(buyer_delta.inventory)

      assert %VendingSaleReport{
               nameid: @potion,
               amount: 4,
               zeny_gained: 400,
               buyer_name: "Buyer"
             } = report
    end

    test "applies the buyer delta to the buyer's in-memory state", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      {:ok, _new_state, buyer_delta, _reports} =
        purchase(seller_state, buyer, %{}, 1_000, stats(buyer), "Buyer", [
          {index, 4}
        ])

      buyer_state = player_state(buyer, %{}, 1_000)

      assert {:ok, applied} = VendingHandler.apply_purchase_as_buyer(buyer_state, buyer_delta)
      assert applied.game_state.zeny == 600

      assert [%InventoryItem{nameid: @potion, amount: 4}] =
               Map.values(applied.game_state.inventory)
    end

    test "insufficient buyer zeny is rejected and writes nothing", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      assert {:error, :not_enough_zeny} =
               purchase(seller_state, buyer, %{}, 100, stats(buyer), "Buyer", [
                 {index, 4}
               ])

      assert_nothing_written(seller, buyer)
    end

    test "a line whose live cart dropped below the request is :sold_out, nothing written", ctx do
      %{seller: seller, buyer: buyer} = ctx
      # Shop still lists 10, but the live cart only holds 3 (sold out since open).
      seller_state = vending_state(seller, [{@potion, 3}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      assert {:error, :sold_out} =
               purchase(seller_state, buyer, %{}, 1_000, stats(buyer), "Buyer", [
                 {index, 5}
               ])

      assert [%CartItem{amount: 3}] = CartPersistence.load_cart(seller.id)
      assert reload_zeny(seller.id) == 1_000_000
      assert reload_zeny(buyer.id) == 1_000
      assert [] = InventoryPersistence.load_inventory(buyer.id)
    end

    test "a forced failure on the buyer insert rolls back all four writes", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      stub(InventoryPersistence, :insert_item, fn _char_id, _attrs ->
        {:error, :forced_failure}
      end)

      assert {:error, :persistence_failed} =
               purchase(seller_state, buyer, %{}, 1_000, stats(buyer), "Buyer", [
                 {index, 4}
               ])

      assert_nothing_written(seller, buyer)
    end

    test "buying the last listed unit auto-closes the shop", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 4}], [{0, 4, 100}])
      index = only_cart_index(seller_state)

      assert {:ok, new_state, _buyer_delta, _reports} =
               purchase(seller_state, buyer, %{}, 1_000, stats(buyer), "Buyer", [
                 {index, 4}
               ])

      assert new_state.game_state.vending_shop == nil
      assert :error = Registry.get(seller.id)
      assert [] = CartPersistence.load_cart(seller.id)
    end

    test "duplicate buy-lines on the same index share the listing", ctx do
      %{seller: seller, buyer: buyer} = ctx
      # Two listings, so two lines stay within the basket's line count.
      seller_state = vending_state(seller, [{@potion, 10}, {@orange, 5}], two_listings())
      index = only_cart_index(seller_state)

      assert {:ok, _new_state, buyer_delta, _reports} =
               purchase(seller_state, buyer, %{}, 1_000, stats(buyer), "Buyer", [
                 {index, 3},
                 {index, 4}
               ])

      assert [%CartItem{amount: 3}] = cart_rows(seller.id, @potion)
      assert [%InventoryItem{amount: 7}] = InventoryPersistence.load_inventory(buyer.id)
      assert buyer_delta.zeny_spent == 700
      assert reload_zeny(seller.id) == 1_000_000 + 700
      assert reload_zeny(buyer.id) == 1_000 - 700
    end

    test "rejects duplicate lines whose sum exceeds stock, preventing over-sell", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}, {@orange, 5}], two_listings())
      index = only_cart_index(seller_state)

      # 6 + 6 = 12 against a 10-stock listing: without accumulation each 6-line
      # would pass the per-line check independently and over-sell 12 from 10.
      # The buyer affords all 12, since funds are checked before stock.
      assert {:error, :insufficient_stock} =
               purchase(seller_state, buyer, %{}, 2_000, stats(buyer), "Buyer", [
                 {index, 6},
                 {index, 6}
               ])

      assert [%CartItem{amount: 10}] = cart_rows(seller.id, @potion)
      assert reload_zeny(seller.id) == 1_000_000
      assert reload_zeny(buyer.id) == 1_000
      assert [] = InventoryPersistence.load_inventory(buyer.id)
    end

    test "an overweight buyer is rejected and writes nothing", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      stats = stats(buyer)
      fill = div(Weight.max_weight(stats), 70)
      seed_inventory(buyer.id, fill)
      buyer_inventory = load_inventory_map(buyer.id)

      assert {:error, :overweight} =
               purchase(seller_state, buyer, buyer_inventory, 1_000, stats, "Buyer", [
                 {index, 1}
               ])

      assert [%CartItem{amount: 10}] = CartPersistence.load_cart(seller.id)
      assert reload_zeny(seller.id) == 1_000_000
      assert reload_zeny(buyer.id) == 1_000

      assert [%InventoryItem{amount: ^fill}] =
               InventoryPersistence.load_inventory(buyer.id)
    end
  end

  describe "settlement rules" do
    test "credits the basket net of tax while each line reports its own tax", ctx do
      %{seller: seller, buyer: buyer} = ctx

      stub(Config, :vending_rules, fn ->
        %{
          call_original(Config, :vending_rules, [])
          | tax: 500,
            tax_min: 500,
            show_buyer_name: false
        }
      end)

      seller_state =
        vending_state(seller, [{@potion, 10}, {@orange, 5}], [{0, 10, 100}, {1, 5, 250}])

      [potion, orange] = seller_state.game_state.cart |> Map.keys() |> Enum.sort()

      # 400 stays under the threshold on its own; 500 and the 900 basket do not.
      assert {:ok, new_state, buyer_delta, reports} =
               purchase(seller_state, buyer, %{}, 1_000, stats(buyer), "Buyer", [
                 {potion, 4},
                 {orange, 2}
               ])

      assert buyer_delta.zeny_spent == 900
      assert reload_zeny(buyer.id) == 100
      assert reload_zeny(seller.id) == 1_000_000 + 855
      assert new_state.game_state.zeny == 1_000_000 + 855
      assert %{total_earned: 855, sale_sequence: 1} = new_state.game_state.vending_shop

      assert [
               %VendingSaleReport{index: ^potion, zeny_gained: 400},
               %VendingSaleReport{index: ^orange, zeny_gained: 475}
             ] = reports

      for report <- reports do
        assert %{shop_id: "purchase-fixture", sale_sequence: 1, total_earned: 855} = report
        assert report.buyer_name == ""
      end
    end

    test "refuses another shop instance, map, range or trade permission", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_gs = vending_state(seller, [{@potion, 10}], [{0, 10, 100}]).game_state
      index = seller_gs.cart |> Map.keys() |> hd()
      rows = [%VendingBuy{index: index, amount: 1, expected_unit_price: 100}]
      near = buyer_gs(buyer, %{}, 1_000, stats(buyer), "Buyer")

      assert {:error, :shop_changed} = VendingHandler.settle(seller_gs, near, "old-shop", rows)

      for {map_name, x, reason} <- [{"geffen", 150, :wrong_map}, {"prontera", 171, :out_of_range}] do
        buyer_gs = %{near | map_name: map_name, x: x}

        assert {:error, ^reason} =
                 VendingHandler.settle(seller_gs, buyer_gs, "purchase-fixture", rows)
      end

      stub(PortalAccess, :trade_permissions, fn
        %{character_id: id} when id == buyer.id -> %{can_trade: false, trade_unconditional: false}
        player -> call_original(PortalAccess, :trade_permissions, [player])
      end)

      assert {:error, :forbidden} =
               VendingHandler.settle(seller_gs, near, "purchase-fixture", rows)

      assert_nothing_written(seller, buyer)
    end
  end

  defp two_listings, do: [{0, 10, 100}, {1, 5, 50}]

  defp cart_rows(char_id, nameid),
    do: char_id |> CartPersistence.load_cart() |> Enum.filter(&(&1.nameid == nameid))

  # Checks out `lines` (`{cart_index, amount}`, quoted at the listed price) from
  # the seller's shop as the buyer's live snapshot, returning the seller state,
  # the buyer delta and the sale reports sent to the seller's client.
  defp purchase(seller_state, buyer, inventory, zeny, stats, name, lines) do
    shop = seller_state.game_state.vending_shop

    buyer_gs = buyer_gs(buyer, inventory, zeny, stats, name)

    rows =
      Enum.map(lines, fn {index, amount} ->
        %ShopItem{price: price} = Enum.find(shop.items, &(&1.cart_index == index))
        %VendingBuy{index: index, amount: amount, expected_unit_price: price}
      end)

    case VendingHandler.handle_purchase(seller_state, buyer_gs, shop.shop_id, rows) do
      {:reply, {:ok, buyer_delta}, new_state} -> {:ok, new_state, buyer_delta, sale_reports()}
      {:reply, {:error, reason}, ^seller_state} -> {:error, reason}
    end
  end

  defp buyer_gs(buyer, inventory, zeny, stats, name) do
    %{
      PlayerState.new(buyer)
      | inventory: inventory,
        zeny: zeny,
        stats: stats,
        character_name: name,
        map_name: "prontera",
        x: 150,
        y: 151
    }
  end

  defp sale_reports do
    receive do
      {:send, _channel, {:vending_sale_report, report}} -> [report | sale_reports()]
    after
      0 -> []
    end
  end

  defp assert_nothing_written(seller, buyer) do
    assert [%CartItem{amount: 10}] = CartPersistence.load_cart(seller.id)
    assert reload_zeny(seller.id) == 1_000_000
    assert reload_zeny(buyer.id) == 1_000
    assert [] = InventoryPersistence.load_inventory(buyer.id)
  end

  defp insert_character(name, zeny) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "u_#{name}_#{System.unique_integer([:positive])}",
        userid: "u_#{name}_#{System.unique_integer([:positive])}",
        user_pass: "password",
        email: "#{name}@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{System.unique_integer([:positive])}",
        class: 1,
        base_level: 99,
        zeny: zeny,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    character
  end

  # Builds a seller with an open shop whose live cart holds `cart_specs` and whose
  # shop lists `shop_specs` (`{cart_slot, listed_amount, price}`), registered.
  defp vending_state(character, cart_specs, shop_specs) do
    Enum.each(cart_specs, fn {nameid, amount} ->
      {:ok, _} = CartPersistence.insert_item(character.id, %{nameid: nameid, amount: amount})
    end)

    cart = load_cart_map(character.id)
    indices = cart |> Map.keys() |> Enum.sort()

    items =
      Enum.map(shop_specs, fn {slot, amount, price} ->
        index = Enum.at(indices, slot)
        %InventoryItem{nameid: nameid} = Map.fetch!(cart, index)
        %ShopItem{cart_index: index, nameid: nameid, amount: amount, price: price}
      end)

    shop = %{
      shop_id: "purchase-fixture",
      title: "Shop",
      owner_char_id: character.id,
      items: items,
      total_earned: 0,
      sale_sequence: 0
    }

    Registry.put(character.id, self(), shop)

    base = PlayerState.new(character)

    game_state = %{
      base
      | cart: cart,
        zeny: character.zeny,
        vending_shop: shop,
        map_name: "prontera",
        x: 150,
        y: 150
    }

    %SessionState{connection_pid: self(), game_state: game_state}
  end

  defp player_state(character, inventory, zeny) do
    base = PlayerState.new(character)
    %SessionState{connection_pid: self(), game_state: %{base | inventory: inventory, zeny: zeny}}
  end

  defp stats(character), do: Stats.from_character(character)

  defp seed_inventory(char_id, amount) do
    {:ok, _} = InventoryPersistence.insert_item(char_id, %{nameid: @potion, amount: amount})
    :ok
  end

  defp load_inventory_map(char_id) do
    items = InventoryPersistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp load_cart_map(char_id) do
    rows = CartPersistence.load_cart(char_id)

    rows
    |> Enum.map(&cart_row_to_item/1)
    |> PlayerState.from_list()
  end

  defp only_cart_index(%{game_state: %{cart: cart}}) do
    cart |> Map.keys() |> List.first()
  end

  defp reload_zeny(char_id), do: Repo.get!(Character, char_id).zeny

  defp cart_row_to_item(%CartItem{} = c) do
    %InventoryItem{
      id: c.id,
      char_id: c.char_id,
      nameid: c.nameid,
      amount: c.amount,
      equip: c.equip,
      identify: c.identify,
      refine: c.refine,
      attribute: c.attribute,
      card0: c.card0,
      card1: c.card1,
      card2: c.card2,
      card3: c.card3,
      random_options: c.random_options,
      bound: c.bound,
      favorite: c.favorite,
      unique_id: c.unique_id,
      expire_time: c.expire_time,
      equip_switch: c.equip_switch,
      enchant_grade: c.enchant_grade
    }
  end
end
