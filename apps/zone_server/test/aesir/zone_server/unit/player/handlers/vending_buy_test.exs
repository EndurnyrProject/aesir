defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingBuyTest do
  @moduledoc """
  DataCase coverage for the seller-authoritative cross-player vending buy
  (`VendingHandler.purchase/7` + `apply_purchase_as_buyer/2`): the four-row
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
  alias Aesir.Net.VendingSaleReport
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Cart.Persistence, as: CartPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Vending.Registry
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  @potion 501

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

  describe "purchase/7" do
    test "transfers cart -> buyer inventory and zeny both ways in one transaction", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      assert {:ok, new_state, buyer_delta, [report]} =
               VendingHandler.purchase(
                 seller_state,
                 buyer.id,
                 %{},
                 1_000,
                 stats(buyer),
                 "Buyer",
                 [
                   {index, 4}
                 ]
               )

      # Seller side: cart row reduced, characters.zeny credited.
      assert {:ok, [%CartItem{nameid: @potion, amount: 6}]} = CartPersistence.load_cart(seller.id)
      assert reload_zeny(seller.id) == 1_000_000 + 400
      assert %{^index => %InventoryItem{amount: 6}} = new_state.game_state.cart
      assert new_state.game_state.zeny == 1_000_000 + 400

      # Buyer side: inventory row inserted, characters.zeny debited.
      assert {:ok, [%InventoryItem{nameid: @potion, amount: 4}]} =
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
        VendingHandler.purchase(seller_state, buyer.id, %{}, 1_000, stats(buyer), "Buyer", [
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
               VendingHandler.purchase(seller_state, buyer.id, %{}, 100, stats(buyer), "Buyer", [
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
               VendingHandler.purchase(
                 seller_state,
                 buyer.id,
                 %{},
                 1_000,
                 stats(buyer),
                 "Buyer",
                 [
                   {index, 5}
                 ]
               )

      assert {:ok, [%CartItem{amount: 3}]} = CartPersistence.load_cart(seller.id)
      assert reload_zeny(seller.id) == 1_000_000
      assert reload_zeny(buyer.id) == 1_000
      assert {:ok, []} = InventoryPersistence.load_inventory(buyer.id)
    end

    test "a forced failure on the buyer insert rolls back all four writes", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      stub(InventoryPersistence, :insert_item, fn _char_id, _attrs ->
        {:error, :forced_failure}
      end)

      assert {:error, :forced_failure} =
               VendingHandler.purchase(
                 seller_state,
                 buyer.id,
                 %{},
                 1_000,
                 stats(buyer),
                 "Buyer",
                 [
                   {index, 4}
                 ]
               )

      assert_nothing_written(seller, buyer)
    end

    test "buying the last listed unit auto-closes the shop", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 4}], [{0, 4, 100}])
      index = only_cart_index(seller_state)

      assert {:ok, new_state, _buyer_delta, _reports} =
               VendingHandler.purchase(
                 seller_state,
                 buyer.id,
                 %{},
                 1_000,
                 stats(buyer),
                 "Buyer",
                 [
                   {index, 4}
                 ]
               )

      assert new_state.game_state.action_state == :idle
      assert :error = Registry.get(seller.id)
      assert {:ok, []} = CartPersistence.load_cart(seller.id)
    end

    test "accumulates duplicate buy-lines on the same index into one removal", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      assert {:ok, _new_state, buyer_delta, _reports} =
               VendingHandler.purchase(
                 seller_state,
                 buyer.id,
                 %{},
                 1_000,
                 stats(buyer),
                 "Buyer",
                 [
                   {index, 3},
                   {index, 4}
                 ]
               )

      assert {:ok, [%CartItem{amount: 3}]} = CartPersistence.load_cart(seller.id)
      assert {:ok, [%InventoryItem{amount: 7}]} = InventoryPersistence.load_inventory(buyer.id)
      assert buyer_delta.zeny_spent == 700
      assert reload_zeny(seller.id) == 1_000_000 + 700
      assert reload_zeny(buyer.id) == 1_000 - 700
    end

    test "rejects duplicate lines whose sum exceeds stock, preventing over-sell", ctx do
      %{seller: seller, buyer: buyer} = ctx
      seller_state = vending_state(seller, [{@potion, 10}], [{0, 10, 100}])
      index = only_cart_index(seller_state)

      # 6 + 6 = 12 against a 10-stock listing: without accumulation each 6-line
      # would pass the per-line check independently and over-sell 12 from 10.
      assert {:error, :bad_line} =
               VendingHandler.purchase(
                 seller_state,
                 buyer.id,
                 %{},
                 1_000,
                 stats(buyer),
                 "Buyer",
                 [
                   {index, 6},
                   {index, 6}
                 ]
               )

      assert_nothing_written(seller, buyer)
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
               VendingHandler.purchase(
                 seller_state,
                 buyer.id,
                 buyer_inventory,
                 1_000,
                 stats,
                 "Buyer",
                 [
                   {index, 1}
                 ]
               )

      assert {:ok, [%CartItem{amount: 10}]} = CartPersistence.load_cart(seller.id)
      assert reload_zeny(seller.id) == 1_000_000
      assert reload_zeny(buyer.id) == 1_000

      assert {:ok, [%InventoryItem{amount: ^fill}]} =
               InventoryPersistence.load_inventory(buyer.id)
    end
  end

  defp assert_nothing_written(seller, buyer) do
    assert {:ok, [%CartItem{amount: 10}]} = CartPersistence.load_cart(seller.id)
    assert reload_zeny(seller.id) == 1_000_000
    assert reload_zeny(buyer.id) == 1_000
    assert {:ok, []} = InventoryPersistence.load_inventory(buyer.id)
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

  # Builds a seller in `:vending` whose live cart holds `cart_specs` and whose
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

    shop = %{title: "Shop", owner_char_id: character.id, items: items}
    Registry.put(character.id, self(), shop)

    base = PlayerState.new(character)

    game_state = %{
      base
      | cart: cart,
        zeny: character.zeny,
        action_state: :vending,
        state_context: shop
    }

    %{connection_pid: self(), game_state: game_state}
  end

  defp player_state(character, inventory, zeny) do
    base = PlayerState.new(character)
    %{connection_pid: self(), game_state: %{base | inventory: inventory, zeny: zeny}}
  end

  defp stats(character), do: Stats.from_character(character)

  defp seed_inventory(char_id, amount) do
    {:ok, _} = InventoryPersistence.insert_item(char_id, %{nameid: @potion, amount: amount})
    :ok
  end

  defp load_inventory_map(char_id) do
    {:ok, items} = InventoryPersistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp load_cart_map(char_id) do
    {:ok, rows} = CartPersistence.load_cart(char_id)

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
