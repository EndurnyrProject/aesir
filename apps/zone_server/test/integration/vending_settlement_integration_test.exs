defmodule Aesir.ZoneServer.Integration.VendingSettlementIntegrationTest do
  @moduledoc """
  Checkout settlement across live `PlayerSession`s through real packet ingress:
  replayed requests, competing buyers on both sides of the seller's character
  id (the seller-settles and buyer-settles paths), a reopened shop, the final
  sold-out report, self-purchase, reciprocal vendors and a seller that vanishes
  before settling an invited checkout.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartMountRequest
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.MoveToCartRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingCloseRequest
  alias Aesir.Net.VendingCloseResult
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingOpenResult
  alias Aesir.Net.VendingPurchaseRequest
  alias Aesir.Net.VendingPurchaseResult
  alias Aesir.Net.VendingSaleReport
  alias Aesir.Net.VendingSetupReady
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Cart.Persistence, as: CartPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @merchant_class 5
  @potion 501
  @push_cart_status :sc_push_cart
  @price 100

  test "a replayed checkout resends its result without charging again" do
    seller = start_seller(zeny: 1_000, cart_stock: 10)
    {shop_id, index} = open_shop(seller, 10)
    buyer = start_buyer(zeny: 5_000)
    request = purchase(seller, shop_id, 1, [{index, 2}])

    simulate_incoming_message(buyer.pid, request)
    assert_result(1, :VEND_PURCHASE_OK, total_charged: 200)
    assert_receive {:packet_sent, %ItemAdded{nameid: @potion}, _}, 1_000
    flush_packets()

    simulate_incoming_message(buyer.pid, request)
    assert_result(1, :VEND_PURCHASE_OK, total_charged: 200)
    refute_receive {:packet_sent, %ItemAdded{}, _}, 200
    refute_received {:packet_sent, %VendingSaleReport{}, _}

    simulate_incoming_message(buyer.pid, purchase(seller, shop_id, 1, [{index, 3}]))
    assert_result(1, :VEND_PURCHASE_STALE_REQUEST)

    assert get_player_state(buyer.pid).zeny == 4_800
    assert Repo.get(Character, buyer.character.id).zeny == 4_800
    assert [%CartItem{amount: 8}] = CartPersistence.load_cart(seller.character.id)
  end

  test "buyers on both sides of the seller's id never sell more than the live stock" do
    low = start_buyer(zeny: 5_000)
    seller = start_seller(zeny: 1_000, cart_stock: 5)
    high = start_buyer(zeny: 5_000)
    assert low.character.id < seller.character.id and seller.character.id < high.character.id
    {shop_id, index} = open_shop(seller, 5)

    :ok = :sys.suspend(seller.pid)
    simulate_incoming_message(low.pid, purchase(seller, shop_id, 1, [{index, 3}]))
    simulate_incoming_message(high.pid, purchase(seller, shop_id, 2, [{index, 3}]))

    assert_eventually(fn ->
      Process.info(seller.pid, :message_queue_len) == {:message_queue_len, 2}
    end)

    :ok = :sys.resume(seller.pid)

    results =
      for request_id <- [1, 2] do
        assert_receive {:packet_sent,
                        %VendingPurchaseResult{request_id: ^request_id, result: result}, _},
                       1_000

        result
      end

    assert Enum.sort(results) == [:VEND_PURCHASE_INSUFFICIENT_STOCK, :VEND_PURCHASE_OK]
    assert [%CartItem{amount: 2}] = CartPersistence.load_cart(seller.character.id)

    bought =
      held(get_player_state(low.pid).inventory, @potion) +
        held(get_player_state(high.pid).inventory, @potion)

    assert bought == 3
    assert get_player_state(seller.pid).zeny == 1_300
  end

  test "an old checkout cannot buy from the vendor's reopened shop" do
    seller = start_seller(zeny: 1_000, cart_stock: 10)
    {old_shop, index} = open_shop(seller, 10)
    buyer = start_buyer(zeny: 5_000)

    simulate_incoming_message(seller.pid, %VendingCloseRequest{
      request_id: 2,
      target: {:shop_id, old_shop}
    })

    assert_receive {:packet_sent, %VendingCloseResult{result: :VEND_CLOSE_SHOP_CLOSED}, _}, 1_000
    {new_shop, ^index} = open_shop(activate_setup(seller), 10)
    assert new_shop != old_shop

    simulate_incoming_message(buyer.pid, purchase(seller, old_shop, 1, [{index, 1}]))

    assert_result(1, :VEND_PURCHASE_SHOP_CHANGED)
    assert get_player_state(buyer.pid).zeny == 5_000
    assert [%CartItem{amount: 10}] = CartPersistence.load_cart(seller.character.id)
  end

  test "the final sold-out report identifies the closed shop" do
    seller = start_seller(zeny: 1_000, cart_stock: 3)
    seller_id = seller.character.id
    {shop_id, index} = open_shop(seller, 3)
    buyer = start_buyer(zeny: 5_000)

    simulate_incoming_message(buyer.pid, purchase(seller, shop_id, 1, [{index, 3}]))

    assert_result(1, :VEND_PURCHASE_OK, total_charged: 300)

    assert_receive {:packet_sent,
                    %VendingSaleReport{
                      amount: 3,
                      shop_id: ^shop_id,
                      sale_sequence: 1,
                      total_earned: 300
                    }, _},
                   1_000

    assert_receive {:packet_sent,
                    %VendingBoardRemoved{
                      unit_id: ^seller_id,
                      shop_id: ^shop_id,
                      reason: :VEND_CLOSURE_SOLD_OUT
                    }, _},
                   1_000

    assert get_player_state(seller.pid).vending_shop == nil
  end

  test "buying from one's own shop is refused and the session stays responsive" do
    seller = start_seller(zeny: 1_000, cart_stock: 10)
    {shop_id, index} = open_shop(seller, 10)

    simulate_incoming_message(seller.pid, purchase(seller, shop_id, 2, [{index, 1}]))

    assert_result(2, :VEND_PURCHASE_SELF_PURCHASE)
    assert get_player_state(seller.pid).vending_shop != nil
  end

  test "two vending merchants can buy from each other without blocking their sessions" do
    left = start_seller(zeny: 1_000, cart_stock: 10)
    right = start_seller(zeny: 1_000, cart_stock: 10)
    {left_shop, left_index} = open_shop(left, 10)
    {right_shop, right_index} = open_shop(right, 10)

    :ok = :sys.suspend(left.pid)
    :ok = :sys.suspend(right.pid)
    simulate_incoming_message(left.pid, purchase(right, right_shop, 2, [{right_index, 1}]))
    simulate_incoming_message(right.pid, purchase(left, left_shop, 2, [{left_index, 1}]))
    :ok = :sys.resume(left.pid)
    :ok = :sys.resume(right.pid)

    for vendor <- [left, right] do
      vendor_id = vendor.character.id

      assert_receive {:packet_sent,
                      %VendingPurchaseResult{
                        vendor_unit_id: ^vendor_id,
                        result: :VEND_PURCHASE_OK
                      }, _},
                     1_000
    end

    for merchant <- [left, right] do
      state = get_player_state(merchant.pid)
      assert state.zeny == 1_000
      assert held(state.cart, @potion) == 9
      assert held(state.inventory, @potion) == 1
    end
  end

  test "a checkout whose invited seller vanishes is answered as closed" do
    seller = start_seller(zeny: 1_000, cart_stock: 10)
    {shop_id, index} = open_shop(seller, 10)
    buyer = start_buyer(zeny: 5_000)

    :ok = :sys.suspend(seller.pid)
    simulate_incoming_message(buyer.pid, purchase(seller, shop_id, 1, [{index, 1}]))

    assert_eventually(fn ->
      Process.info(seller.pid, :message_queue_len) == {:message_queue_len, 1}
    end)

    Process.unlink(seller.pid)
    Process.exit(seller.pid, :kill)

    assert_result(1, :VEND_PURCHASE_NOT_OPEN)
    assert get_player_state(buyer.pid).zeny == 5_000
  end

  defp purchase(vendor, shop_id, request_id, lines) do
    %VendingPurchaseRequest{
      request_id: request_id,
      vendor_unit_id: vendor.character.id,
      shop_id: shop_id,
      items:
        Enum.map(lines, fn {index, amount} ->
          %VendingBuy{index: index, amount: amount, expected_unit_price: @price}
        end)
    }
  end

  defp assert_result(request_id, code, fields \\ []) do
    assert_receive {:packet_sent,
                    %VendingPurchaseResult{request_id: ^request_id, result: ^code} = result, _},
                   1_000

    for {field, value} <- fields, do: assert(Map.fetch!(result, field) == value)
  end

  # Opens the seller's prepared shop listing `amount` cart potions at `@price`;
  # returns the shop ID and the listing index buyers echo.
  defp open_shop(seller, amount) do
    seller_id = seller.character.id
    index = only_cart_index(seller.pid)

    simulate_incoming_message(seller.pid, %VendingOpenRequest{
      request_id: 1,
      setup_id: seller.setup_id,
      title: "Pots",
      entries: [%VendingEntry{cart_index: index, amount: amount, price: @price}]
    })

    assert_receive {:packet_sent,
                    %VendingOpenResult{vendor_unit_id: ^seller_id, result: :VEND_OK, shop_id: id},
                    _},
                   1_000

    assert_receive {:packet_sent, %VendingBoardShown{unit_id: ^seller_id, shop_id: ^id}, _}, 1_000
    flush_packets()
    {id, index}
  end

  defp start_seller(opts) do
    character =
      insert_character("Merchy",
        class: @merchant_class,
        zeny: Keyword.fetch!(opts, :zeny),
        skill_point: 20,
        sp: 100,
        max_sp: 100
      )

    cart_stock = Keyword.fetch!(opts, :cart_stock)

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
    learn_levels(session.pid, :mc_inccarry, 5)
    learn_levels(session.pid, :mc_pushcart, 3)
    learn(session.pid, :mc_vending, 1)
    simulate_incoming_message(session.pid, %CartMountRequest{mount: true})
    assert_receive {:packet_sent, %CartInfo{}, _}, 1_000

    inv_index = client_index_of(get_player_state(session.pid).inventory, @potion)

    simulate_incoming_message(session.pid, %MoveToCartRequest{
      inventory_index: inv_index,
      amount: cart_stock
    })

    assert_receive {:packet_sent, %CartItemAdded{nameid: @potion}, _}, 1_000
    flush_packets()

    session |> Map.put(:character, character) |> activate_setup()
  end

  # Uses Vending, whose paid setup grant the next open must name.
  defp activate_setup(session) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 41,
      level: 1,
      target_id: session.character.id
    })

    assert_receive {:packet_sent, %VendingSetupReady{setup_id: setup_id}, _}, 1_000
    flush_packets()
    Map.put(session, :setup_id, setup_id)
  end

  defp start_buyer(opts) do
    character = insert_character("Buyer", class: 0, zeny: Keyword.fetch!(opts, :zeny))

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

  defp learn_levels(pid, skill_name, levels) do
    Enum.each(1..levels, &learn(pid, skill_name, &1))
  end

  defp learn(pid, skill_name, expected_level) do
    {:ok, definition} = Catalog.by_name(skill_name)
    skill_id = definition.id
    simulate_incoming_message(pid, %LearnSkill{skill_id: skill_id})
    assert_receive {:packet_sent, %SkillList{skills: skills}, _}, 1_000

    assert %SkillInfo{skill_id: ^skill_id, level: ^expected_level} =
             Enum.find(skills, &(&1.skill_id == skill_id))
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
