defmodule Aesir.ZoneServer.Integration.VendingLifecycleIntegrationTest do
  @moduledoc """
  Vending lifecycle locks and relocation across live `PlayerSession`s through
  real packet ingress: preparation and an open shop lock the cart both ways and
  keep the vendor from walking, attacking or trading; a viewer sees the board
  with its shop identity; a permitted warp keeps the shop and resyncs its owner
  after the map loads, while a `novending` destination closes it; and a
  vendor's death leaves the shop open.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartItemRemoved
  alias Aesir.Net.CartMountRequest
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MapMove
  alias Aesir.Net.MoveFromCartRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveToCartRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.Net.TradeCancelled
  alias Aesir.Net.TradeRequest
  alias Aesir.Net.TradeRequestReceived
  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown
  alias Aesir.Net.VendingCloseRequest
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingOpenResult
  alias Aesir.Net.VendingSetupReady
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Vending.Registry, as: VendingRegistry

  @merchant_class 5
  @potion 501
  @orange 502
  @push_cart_status :sc_push_cart
  @price 100

  test "preparation and an open shop lock the cart both ways until the shop closes" do
    seller = start_seller()

    for phase <- [:setup, :open] do
      if phase == :open, do: open_shop(seller)

      simulate_incoming_message(seller.pid, %MoveFromCartRequest{
        cart_index: client_index_of(get_player_state(seller.pid).cart, @potion),
        amount: 1
      })

      simulate_incoming_message(seller.pid, %MoveToCartRequest{
        inventory_index: client_index_of(get_player_state(seller.pid).inventory, @orange),
        amount: 1
      })

      refute_receive {:packet_sent, %CartItemRemoved{}, _}, 200
      refute_received {:packet_sent, %CartItemAdded{}, _}
      assert held(get_player_state(seller.pid).cart, @potion) == 10
    end

    %{vending_shop: %{shop_id: shop_id}} = get_player_state(seller.pid)

    simulate_incoming_message(seller.pid, %VendingCloseRequest{
      request_id: 9,
      target: {:shop_id, shop_id}
    })

    assert_receive {:packet_sent, %VendingBoardRemoved{shop_id: ^shop_id}, _}, 1_000

    simulate_incoming_message(seller.pid, %MoveFromCartRequest{
      cart_index: client_index_of(get_player_state(seller.pid).cart, @potion),
      amount: 1
    })

    assert_receive {:packet_sent, %CartItemRemoved{amount: 1}, _}, 1_000
  end

  test "a vendor neither walks, attacks nor trades, and nobody can trade with it" do
    seller = start_seller()
    shop_id = open_shop(seller)
    buyer = start_buyer()
    seller_id = seller.character.id
    buyer_id = buyer.character.id

    simulate_incoming_message(seller.pid, %MoveRequest{dest_x: 155, dest_y: 155})
    simulate_incoming_message(seller.pid, %ActionRequest{target_id: buyer_id, action: 7})
    simulate_incoming_message(seller.pid, %TradeRequest{target_gid: buyer_id})
    refute_receive {:packet_sent, %TradeRequestReceived{}, _}, 200

    vendor = get_player_state(seller.pid)
    assert {vendor.x, vendor.y} == {150, 150}
    assert vendor.combat_target_id == nil
    assert %{shop_id: ^shop_id} = vendor.vending_shop

    simulate_incoming_message(buyer.pid, %TradeRequest{target_gid: seller_id})
    assert_receive {:packet_sent, %TradeCancelled{reason: :TRADE_CANCEL_REASON_BUSY}, _}, 1_000
  end

  test "a player entering view sees the board with its shop identity" do
    seller = start_seller()
    seller_id = seller.character.id
    shop_id = open_shop(seller)

    character = insert_character("Viewer", class: 0, zeny: 0)

    viewer =
      start_player_session(character: character, map_name: "prontera", position: {151, 151})

    on_exit(fn -> end_player_session(viewer) end)

    assert_receive {:packet_sent,
                    %VendingBoardShown{unit_id: ^seller_id, title: "Pots", shop_id: ^shop_id}, _},
                   1_000
  end

  test "a permitted warp keeps the shop and resyncs its owner after the map loads" do
    seller = start_seller()
    seller_id = seller.character.id
    shop_id = open_shop(seller)

    PlayerSession.warp(seller.pid, "prontera", 156, 152)
    assert_receive {:packet_sent, %MapMove{map_name: "prontera"}, _}, 1_000
    simulate_incoming_message(seller.pid, %MapLoaded{})

    assert_receive {:packet_sent,
                    %VendingList{
                      request_id: 0,
                      vendor_unit_id: ^seller_id,
                      shop_id: ^shop_id,
                      result: :VEND_LIST_OK
                    }, _},
                   1_000

    assert_receive {:packet_sent, %VendingBoardShown{unit_id: ^seller_id, shop_id: ^shop_id}, _},
                   1_000

    assert {:ok, %{shop_id: ^shop_id}} = VendingRegistry.get(seller_id)
  end

  test "a warp onto a novending map closes the shop and its owner learns it has none" do
    start_per_test_map("geffen")
    seller = start_seller()
    seller_id = seller.character.id
    shop_id = open_shop(seller)
    :ok = MapFlags.set_runtime("geffen", :novending, true)

    try do
      PlayerSession.warp(seller.pid, "geffen", 119, 59)

      assert_receive {:packet_sent,
                      %ChatMessage{gid: ^seller_id, message: "You can't open a shop on this map"},
                      _},
                     1_000

      assert_receive {:packet_sent,
                      %VendingBoardRemoved{shop_id: ^shop_id, reason: :VEND_CLOSURE_RELOCATED},
                      _},
                     1_000

      assert_receive {:packet_sent, %MapMove{map_name: "geffen"}, _}, 1_000
      assert :error = VendingRegistry.get(seller_id)

      simulate_incoming_message(seller.pid, %MapLoaded{})

      assert_receive {:packet_sent,
                      %VendingList{
                        request_id: 0,
                        vendor_unit_id: ^seller_id,
                        result: :VEND_LIST_NOT_OPEN
                      }, _},
                     1_000
    after
      MapFlags.clear_runtime("geffen", :novending)
    end
  end

  test "a vendor's death leaves its shop open" do
    seller = start_seller()
    seller_id = seller.character.id
    shop_id = open_shop(seller)

    PlayerSession.apply_damage(seller.pid, 1_000_000)

    assert_eventually(fn -> get_player_state(seller.pid).action_state == :dead end)
    assert %{shop_id: ^shop_id} = get_player_state(seller.pid).vending_shop
    assert {:ok, %{shop_id: ^shop_id}} = VendingRegistry.get(seller_id)
    refute_received {:packet_sent, %VendingBoardRemoved{}, _}
  end

  # Opens the prepared shop listing all ten cart potions and returns its ID.
  defp open_shop(seller) do
    seller_id = seller.character.id
    index = seller.pid |> get_player_state() |> Map.fetch!(:cart) |> Map.keys() |> hd()

    simulate_incoming_message(seller.pid, %VendingOpenRequest{
      request_id: 1,
      setup_id: seller.setup_id,
      title: "Pots",
      entries: [%VendingEntry{cart_index: index, amount: 10, price: @price}]
    })

    assert_receive {:packet_sent,
                    %VendingOpenResult{vendor_unit_id: ^seller_id, result: :VEND_OK, shop_id: id},
                    _},
                   1_000

    flush_packets()
    id
  end

  # A Merchant with ten potions in a mounted cart, an orange potion left in its
  # inventory, and a paid Vending preparation.
  defp start_seller do
    character =
      insert_character("Merchy",
        class: @merchant_class,
        zeny: 1_000,
        skill_point: 20,
        sp: 100,
        max_sp: 100
      )

    for {nameid, amount} <- [{@potion, 10}, {@orange, 1}] do
      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: nameid,
          amount: amount,
          identify: 1
        })
    end

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> StatusStorage.remove_status(:player, character.id, @push_cart_status) end)

    flush_packets()
    learn_levels(session.pid, :mc_inccarry, 5)
    learn_levels(session.pid, :mc_pushcart, 3)
    learn(session.pid, :mc_vending, 1)
    simulate_incoming_message(session.pid, %CartMountRequest{mount: true})
    assert_receive {:packet_sent, %CartInfo{}, _}, 1_000

    simulate_incoming_message(session.pid, %MoveToCartRequest{
      inventory_index: client_index_of(get_player_state(session.pid).inventory, @potion),
      amount: 10
    })

    assert_receive {:packet_sent, %CartItemAdded{nameid: @potion}, _}, 1_000
    flush_packets()

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 41,
      level: 1,
      target_id: character.id
    })

    assert_receive {:packet_sent, %VendingSetupReady{setup_id: setup_id}, _}, 1_000
    flush_packets()
    session |> Map.put(:character, character) |> Map.put(:setup_id, setup_id)
  end

  defp start_buyer do
    character =
      insert_character("Buyer",
        class: 0,
        zeny: 5_000,
        learned_skills: %{"1" => 9},
        skill_point: 0
      )

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
