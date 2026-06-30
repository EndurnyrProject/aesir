defmodule Aesir.ZoneServer.Integration.VendingIntegrationTest do
  @moduledoc """
  End-to-end coverage that the Merchant vending subsystem is playable on the real
  stack across two live `PlayerSession`s. Every step drives the live
  session/handler/registry/persistence subsystems through the client-intent
  packets (no re-stubbing of units already unit-tested):

    1. A merchant learns `MC_PUSHCART` + `MC_VENDING`, mounts a cart, stocks it,
       and opens a shop: the title board area-broadcasts (`VendingBoardShown`) and
       the `Vending.Registry` holds the live shop.
    2. A second player browses (`VendingListRequest` -> `VendingList`) and buys a
       partial amount: zeny + items transfer **both** ways (seller cart down +
       zeny up, buyer inventory up + zeny down) across the two DB rows, the seller
       gets a `VendingSaleReport`, and a re-browse reflects the reduced listing.
    3. Buying the last unit auto-closes the shop: the board is removed, the
       registry entry is gone, and the seller returns to `:idle`.
    4. Disconnecting a vendor tears the shop down while the unsold cart stock stays
       persisted (no item loss).
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartItemRemoved
  alias Aesir.Net.CartMountRequest
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.MoveToCartRequest
  alias Aesir.Net.ParamChange
  alias Aesir.Net.SkillList
  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingCloseRequest
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingListRequest
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingPurchaseRequest
  alias Aesir.Net.VendingSaleReport
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Cart.Persistence, as: CartPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Vending.Registry, as: VendingRegistry

  # rAthena class id for the 1st-class Merchant; PlayerState derives job_id from it.
  @merchant_class 5
  # Red Potion (item db, weight 70) — a plain stackable to vend.
  @potion 501
  @push_cart_status :sc_push_cart
  @zeny_param StatusParams.zeny()
  @price 100

  describe "vending lifecycle" do
    test "open -> browse -> buy both ways -> list refresh -> last unit auto-closes" do
      seller = start_seller(zeny: 1_000, cart_stock: 10)
      buyer = start_buyer(zeny: 5_000)

      seller_id = seller.character.id
      cart_index = only_cart_index(seller.pid)

      # 1. Open the shop: listing all 10 potions at 100z.
      simulate_incoming_message(seller.pid, %VendingOpenRequest{
        title: "Cheap Pots",
        entries: [%VendingEntry{cart_index: cart_index, amount: 10, price: @price}]
      })

      assert_receive {:packet_sent, %VendingBoardShown{unit_id: ^seller_id, title: "Cheap Pots"},
                      _},
                     1_000

      assert {:ok, %{title: "Cheap Pots"}} = VendingRegistry.get(seller_id)
      assert get_player_state(seller.pid).action_state == :vending
      flush_packets()

      # 2. Buyer browses the live shop.
      simulate_incoming_message(buyer.pid, %VendingListRequest{vendor_unit_id: seller_id})

      assert_receive {:packet_sent,
                      %VendingList{
                        vendor_unit_id: ^seller_id,
                        items: [%{nameid: @potion} = listing]
                      }, _},
                     1_000

      assert listing.amount == 10
      buy_index = listing.index

      # 3. Buyer buys 4 -> zeny + items transfer both ways.
      simulate_incoming_message(buyer.pid, %VendingPurchaseRequest{
        vendor_unit_id: seller_id,
        items: [%VendingBuy{index: buy_index, amount: 4}]
      })

      # Seller-side client deltas: cart removed, zeny credited, sale report.
      assert_receive {:packet_sent, %CartItemRemoved{amount: 4}, _}, 1_000

      assert_receive {:packet_sent,
                      %VendingSaleReport{
                        nameid: @potion,
                        amount: 4,
                        zeny_gained: 400,
                        buyer_name: buyer_name
                      }, _},
                     1_000

      assert buyer_name == buyer.character.name

      # Buyer-side client deltas: item added, zeny debited.
      assert_receive {:packet_sent, %ItemAdded{nameid: @potion}, _}, 1_000
      assert_receive {:packet_sent, %ParamChange{var_id: @zeny_param, value: 4_600}, _}, 1_000

      # In-memory both ways.
      seller_after = get_player_state(seller.pid)
      buyer_after = get_player_state(buyer.pid)
      assert held(seller_after.cart, @potion) == 6
      assert seller_after.zeny == 1_400
      assert held(buyer_after.inventory, @potion) == 4
      assert buyer_after.zeny == 4_600

      # Persisted both ways.
      assert [%CartItem{nameid: @potion, amount: 6}] = CartPersistence.load_cart(seller_id)
      assert Repo.get(Character, seller_id).zeny == 1_400

      assert [%InventoryItem{nameid: @potion, amount: 4}] =
               InventoryPersistence.load_inventory(buyer.character.id)

      assert Repo.get(Character, buyer.character.id).zeny == 4_600

      # 4. Re-browse: the listing now reflects the reduced amount.
      flush_packets()
      simulate_incoming_message(buyer.pid, %VendingListRequest{vendor_unit_id: seller_id})

      assert_receive {:packet_sent, %VendingList{items: [%{nameid: @potion, amount: 6}]}, _},
                     1_000

      # 5. Buy the remaining 6 -> shop auto-closes.
      flush_packets()

      simulate_incoming_message(buyer.pid, %VendingPurchaseRequest{
        vendor_unit_id: seller_id,
        items: [%VendingBuy{index: buy_index, amount: 6}]
      })

      assert_receive {:packet_sent, %VendingBoardRemoved{unit_id: ^seller_id}, _}, 1_000

      assert :error = VendingRegistry.get(seller_id)
      assert get_player_state(seller.pid).action_state == :idle
      assert [] = CartPersistence.load_cart(seller_id)

      # Both buys of the identified potion stack into a single buyer slot (4 + 6).
      assert held(get_player_state(buyer.pid).inventory, @potion) == 10

      assert [%InventoryItem{nameid: @potion, amount: 10}] =
               InventoryPersistence.load_inventory(buyer.character.id)
    end

    test "disconnecting a vendor closes the shop and leaves the unsold stock in the cart" do
      seller = start_seller(zeny: 1_000, cart_stock: 10)
      seller_id = seller.character.id
      cart_index = only_cart_index(seller.pid)

      simulate_incoming_message(seller.pid, %VendingOpenRequest{
        title: "Closing Soon",
        entries: [%VendingEntry{cart_index: cart_index, amount: 10, price: @price}]
      })

      assert_receive {:packet_sent, %VendingBoardShown{unit_id: ^seller_id}, _}, 1_000
      assert {:ok, _shop} = VendingRegistry.get(seller_id)

      # Disconnect: terminate/2 tears the shop down via close_shop.
      end_player_session(seller)

      assert :error = VendingRegistry.get(seller_id)

      # No item loss: the unsold cart stock is still persisted.
      assert [%CartItem{nameid: @potion, amount: 10}] =
               CartPersistence.load_cart(seller_id)
    end

    test "an explicit close keeps the cart stock and returns the merchant to idle" do
      seller = start_seller(zeny: 1_000, cart_stock: 10)
      seller_id = seller.character.id
      cart_index = only_cart_index(seller.pid)

      simulate_incoming_message(seller.pid, %VendingOpenRequest{
        title: "Bye",
        entries: [%VendingEntry{cart_index: cart_index, amount: 10, price: @price}]
      })

      assert_receive {:packet_sent, %VendingBoardShown{unit_id: ^seller_id}, _}, 1_000
      flush_packets()

      simulate_incoming_message(seller.pid, %VendingCloseRequest{})

      assert_receive {:packet_sent, %VendingBoardRemoved{unit_id: ^seller_id}, _}, 1_000

      assert :error = VendingRegistry.get(seller_id)
      closed = get_player_state(seller.pid)
      assert closed.action_state == :idle
      assert held(closed.cart, @potion) == 10

      assert [%CartItem{nameid: @potion, amount: 10}] =
               CartPersistence.load_cart(seller_id)
    end
  end

  # Starts a Merchant with MC_PUSHCART + MC_VENDING learned, a mounted cart, and
  # `cart_stock` potions moved into the cart, ready to open a shop.
  defp start_seller(opts) do
    zeny = Keyword.fetch!(opts, :zeny)
    cart_stock = Keyword.fetch!(opts, :cart_stock)

    character = insert_character("Merchy", class: @merchant_class, zeny: zeny, skill_point: 20)

    {:ok, _} =
      InventoryPersistence.insert_item(character.id, %{
        nameid: @potion,
        amount: cart_stock,
        identify: 1
      })

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> StatusStorage.remove_status(:player, character.id, @push_cart_status) end)

    flush_packets()
    learn(session.pid, :mc_pushcart)
    learn(session.pid, :mc_vending)
    mount!(session.pid)

    inv_index = client_index_of(get_player_state(session.pid).inventory, @potion)

    simulate_incoming_message(session.pid, %MoveToCartRequest{
      inventory_index: inv_index,
      amount: cart_stock
    })

    assert_receive {:packet_sent, %CartItemAdded{nameid: @potion}, _}, 1_000
    flush_packets()

    Map.put(session, :character, character)
  end

  defp start_buyer(opts) do
    zeny = Keyword.fetch!(opts, :zeny)
    character = insert_character("Buyer", class: 0, zeny: zeny)

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 151})

    on_exit(fn -> end_player_session(session) end)
    flush_packets()

    Map.put(session, :character, character)
  end

  defp insert_character(prefix, attrs) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "#{prefix}#{uniq}",
        userid: "#{prefix}#{uniq}",
        user_pass: "password",
        email: "#{prefix}#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(
        Map.merge(
          %{
            account_id: account.id,
            char_num: 0,
            name: "#{prefix}#{uniq}",
            class: 0,
            base_level: 50,
            job_level: 50,
            str: 10,
            agi: 10,
            vit: 10,
            int: 10,
            dex: 10,
            luk: 10,
            last_map: "prontera",
            last_x: 150,
            last_y: 150,
            save_map: "prontera",
            save_x: 150,
            save_y: 150
          },
          Map.new(attrs)
        )
      )
      |> Repo.insert()

    character
  end

  defp learn(pid, skill_name) do
    {:ok, definition} = Catalog.by_name(skill_name)
    simulate_incoming_message(pid, %LearnSkill{skill_id: definition.id})
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end

  defp mount!(pid) do
    simulate_incoming_message(pid, %CartMountRequest{mount: true})
    assert_receive {:packet_sent, %CartInfo{}, _}, 1_000
  end

  defp only_cart_index(pid) do
    pid |> get_player_state() |> Map.fetch!(:cart) |> Map.keys() |> List.first()
  end

  defp client_index_of(map, nameid) do
    {server_index, _item} = Enum.find(map, fn {_index, item} -> item.nameid == nameid end)
    PlayerState.client_index(server_index)
  end

  defp held(map, nameid) do
    Enum.reduce(map, 0, fn
      {_index, %InventoryItem{nameid: ^nameid, amount: amount}}, acc -> acc + amount
      _entry, acc -> acc
    end)
  end
end
