defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingSetupTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Auth
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.VendingCloseRequest
  alias Aesir.Net.VendingCloseResult
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingListRequest
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingOpenResult
  alias Aesir.Net.VendingSetupReady
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending.Registry

  setup :setup_ets_tables
  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 400, 400)})
    stub(Auth, :get_account!, fn 2000 -> %Account{id: 2000, group_id: 0} end)
    stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> :ok end)
    stub(NpcRegistry, :entries, fn -> [] end)
    stub(Warps, :for_map, fn _map -> :error end)
    stub(Shops, :for_map, fn _map -> :error end)
    pid = self()

    stub(Broadcast, :to_player, fn 7001, packet ->
      send(pid, {:to_player, packet})
      :ok
    end)

    :ok
  end

  defp session(sp) do
    character = %Character{
      id: 7001,
      account_id: 2000,
      name: "Merchant",
      class: 5,
      sex: "M",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      base_level: 99,
      job_level: 50,
      hp: 800,
      sp: sp,
      str: 10,
      agi: 10,
      vit: 10,
      int: 50,
      dex: 10,
      luk: 10,
      learned_skills: %{"41" => 3}
    }

    caster = %{
      PlayerState.new(character)
      | cart_type: 1,
        cart: %{0 => %InventoryItem{nameid: 501, amount: 5, identify: 1, bound: 0}}
    }

    :ok = UnitRegistry.register_player(caster, self())
    :ok = StatusStorage.apply_status(:player, 7001, :sc_push_cart, val1: 1, val2: 1)
    %SessionState{game_state: caster, connection_pid: self()}
  end

  test "the normal skill pays SP before staging vending preparation" do
    caster = session(300).game_state
    assert {:ok, paid} = Interpreter.cast(caster, 41, 3, :self)
    assert paid.stats.current_state.sp == 270
    assert paid.pending_vending_setup == %{level: 3}
  end

  test "the owning skill handler publishes preparation only after payment" do
    state = session(300)
    state = put_in(state.game_state.stats.modifiers.equipment, %{sp_cost_rate: -50})
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(state, 41, 3, 7001)

    assert_receive {:send, :world,
                    {:vending_setup_ready,
                     %VendingSetupReady{
                       setup_id: setup_id,
                       max_slots: 5,
                       sp_spent: 15,
                       sellable_cart_indices: [0]
                     }}}

    assert is_binary(setup_id) and setup_id != ""
    assert prepared.game_state.stats.current_state.sp == 285
    assert prepared.vending_setup.setup_id == setup_id
    assert prepared.work_in_progress
    assert prepared.game_state.pending_vending_setup == nil
  end

  test "an outstanding setup blocks another activation without charging again" do
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(session(300), 41, 3, 7001)
    assert_receive {:send, :world, {:vending_setup_ready, _grant}}

    assert {:noreply, unchanged} = SkillHandler.handle_use_skill(prepared, 41, 3, 7001)

    assert unchanged.game_state.stats.current_state.sp ==
             prepared.game_state.stats.current_state.sp

    assert unchanged.vending_setup == prepared.vending_setup
    refute_received {:send, :world, {:vending_setup_ready, _}}
  end

  test "canceling releases preparation without refund and cannot cancel a later grant" do
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(session(300), 41, 3, 7001)
    old_id = prepared.vending_setup.setup_id
    cancel = %VendingCloseRequest{request_id: 1, target: {:setup_id, old_id}}

    assert {:noreply, canceled} = VendingHandler.handle_close(prepared, cancel)
    assert canceled.vending_setup == nil
    refute canceled.work_in_progress

    assert canceled.game_state.stats.current_state.sp ==
             prepared.game_state.stats.current_state.sp

    assert_received {:send, :world,
                     {:vending_close_result,
                      %VendingCloseResult{
                        request_id: 1,
                        target: {:setup_id, ^old_id},
                        result: :VEND_CLOSE_SETUP_CANCELED
                      }}}

    assert {:noreply, restarted} = SkillHandler.handle_use_skill(canceled, 41, 3, 7001)
    assert restarted.vending_setup.setup_id != old_id

    assert {:noreply, ^restarted} =
             VendingHandler.handle_close(restarted, %{cancel | request_id: 2})

    assert_received {:send, :world,
                     {:vending_close_result,
                      %VendingCloseResult{
                        request_id: 2,
                        target: {:setup_id, ^old_id},
                        result: :VEND_CLOSE_INVALID_TARGET
                      }}}
  end

  test "opening consumes the paid grant without another SP charge or moving cart stock" do
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(session(40), 41, 3, 7001)
    setup_id = prepared.vending_setup.setup_id

    request = %VendingOpenRequest{
      request_id: 3,
      setup_id: setup_id,
      title: "Cheap Potions",
      entries: [%VendingEntry{cart_index: 0, amount: 3, price: 120}]
    }

    assert {:noreply, ^prepared} =
             VendingHandler.handle_open(prepared, %{request | request_id: 2, setup_id: "stale"})

    assert_received {:send, :world,
                     {:vending_open_result,
                      %VendingOpenResult{
                        request_id: 2,
                        result: :VEND_SETUP_EXPIRED,
                        setup_active: false
                      }}}

    assert {:noreply, opened} = VendingHandler.handle_open(prepared, request)
    assert opened.game_state.stats.current_state.sp == 10
    assert opened.game_state.cart[0].amount == 5
    assert opened.game_state.action_state == :vending
    assert opened.vending_setup == nil
    refute opened.work_in_progress

    assert_received {:send, :world,
                     {:vending_open_result,
                      %VendingOpenResult{
                        request_id: 3,
                        setup_id: ^setup_id,
                        result: :VEND_OK,
                        vendor_unit_id: 7001,
                        shop_id: shop_id,
                        title: "Cheap Potions",
                        items: [item]
                      }}}

    assert shop_id != ""
    assert item.index == 0 and item.amount == 3 and item.price == 120
    assert opened.game_state.state_context.shop_id == shop_id
  end

  test "a missing shop returns a correlated list refusal instead of silence" do
    state = session(300)
    request = %VendingListRequest{request_id: 9, vendor_unit_id: 9999, expected_shop_id: "closed"}
    assert {:noreply, ^state} = VendingHandler.handle_list(state, request)

    assert_received {:send, :world,
                     {:vending_list,
                      %VendingList{
                        request_id: 9,
                        vendor_unit_id: 9999,
                        result: :VEND_LIST_NOT_OPEN
                      }}}
  end

  test "submission rechecks map and cell bans without spending or discarding the grant" do
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(session(300), 41, 3, 7001)

    request = %VendingOpenRequest{
      request_id: 11,
      setup_id: prepared.vending_setup.setup_id,
      title: "Shop",
      entries: [%VendingEntry{cart_index: 0, amount: 1, price: 100}]
    }

    :ok = MapFlags.set_runtime("prontera", :novending, true)
    assert {:noreply, refused} = VendingHandler.handle_open(prepared, request)

    assert_received {:send, :world,
                     {:vending_open_result,
                      %VendingOpenResult{
                        request_id: 11,
                        result: :VEND_MAP_RESTRICTED,
                        setup_active: true
                      }}}

    assert refused.vending_setup == prepared.vending_setup
    assert refused.game_state.stats.current_state.sp == prepared.game_state.stats.current_state.sp

    :ok = MapFlags.set_runtime("prontera", :novending, false)
    [{"prontera", map}] = :ets.lookup(EtsTable.table_for(:map_cache), "prontera")
    map = MapData.set_cell_flag(map, 150, 150, :novending, true)
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})

    assert {:noreply, ^prepared} =
             VendingHandler.handle_open(prepared, %{request | request_id: 12})

    assert_received {:send, :world,
                     {:vending_open_result,
                      %VendingOpenResult{
                        request_id: 12,
                        result: :VEND_CELL_RESTRICTED,
                        setup_active: true
                      }}}
  end

  test "a room prohibition after payment keeps the grant but refuses shop creation" do
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(session(300), 41, 3, 7001)
    :ok = StatusStorage.apply_status(:player, 7001, :sc_nochat, val1: 0x10)

    request = %VendingOpenRequest{
      request_id: 13,
      setup_id: prepared.vending_setup.setup_id,
      title: "Shop",
      entries: [%VendingEntry{cart_index: 0, amount: 1, price: 100}]
    }

    assert {:noreply, refused} = VendingHandler.handle_open(prepared, request)

    assert_received {:send, :world,
                     {:vending_open_result,
                      %VendingOpenResult{
                        request_id: 13,
                        result: :VEND_FORBIDDEN,
                        setup_active: true
                      }}}

    assert refused.vending_setup == prepared.vending_setup
    assert refused.game_state.stats.current_state.sp == prepared.game_state.stats.current_state.sp
  end

  test "preparing a shop does not broadcast a spell animation" do
    pid = self()

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(pid, {:skill_visual, packet})
      :ok
    end)

    assert {:noreply, _prepared} = SkillHandler.handle_use_skill(session(300), 41, 3, 7001)
    assert_received {:send, :world, {:vending_setup_ready, _}}
    refute_received {:skill_visual, %SkillEffect{skill_id: 41}}
  end

  test "browse and close are scoped to the current shop and earnings remain owner-private" do
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(session(300), 41, 3, 7001)

    request = %VendingOpenRequest{
      request_id: 14,
      setup_id: prepared.vending_setup.setup_id,
      title: "Shop",
      entries: [%VendingEntry{cart_index: 0, amount: 3, price: 100}]
    }

    assert {:noreply, opened} = VendingHandler.handle_open(prepared, request)
    shop = %{opened.game_state.state_context | total_earned: 200}
    opened = put_in(opened.game_state.state_context, shop)
    Registry.put(7001, self(), shop)
    assert ^opened = VendingHandler.publish_owner_snapshot(opened)

    assert_received {:send, :world,
                     {:vending_list,
                      %VendingList{
                        request_id: 0,
                        vendor_unit_id: 7001,
                        result: :VEND_LIST_OK,
                        total_earned: 200
                      }}}

    stub(Auth, :get_account!, fn id when id in [2000, 3000] -> %Account{id: id, group_id: 0} end)

    buyer = %{
      opened
      | game_state: %{
          opened.game_state
          | character_id: 7003,
            account_id: 3000,
            action_state: :idle,
            state_context: %{},
            cart: %{}
        }
    }

    stale = %VendingListRequest{request_id: 15, vendor_unit_id: 7001, expected_shop_id: "older"}
    assert {:noreply, ^buyer} = VendingHandler.handle_list(buyer, stale)

    assert_received {:send, :world,
                     {:vending_list,
                      %VendingList{request_id: 15, result: :VEND_LIST_SHOP_CHANGED}}}

    assert {:noreply, ^buyer} =
             VendingHandler.handle_list(
               buyer,
               %{stale | request_id: 16, expected_shop_id: shop.shop_id}
             )

    assert_received {:send, :world,
                     {:vending_list,
                      %VendingList{request_id: 16, result: :VEND_LIST_OK, total_earned: 0}}}

    wrong_close = %VendingCloseRequest{request_id: 17, target: {:shop_id, "older"}}
    assert {:noreply, ^opened} = VendingHandler.handle_close(opened, wrong_close)

    assert_received {:send, :world,
                     {:vending_close_result,
                      %VendingCloseResult{request_id: 17, result: :VEND_CLOSE_INVALID_TARGET}}}

    assert {:ok, ^shop} = Registry.get(7001)

    assert {:noreply, closed} =
             VendingHandler.handle_close(
               opened,
               %{wrong_close | request_id: 18, target: {:shop_id, shop.shop_id}}
             )

    assert closed.game_state.action_state == :idle
    assert closed.game_state.cart == opened.game_state.cart
    assert :error = Registry.get(7001)

    assert_received {:send, :world,
                     {:vending_close_result,
                      %VendingCloseResult{request_id: 18, result: :VEND_CLOSE_SHOP_CLOSED}}}
  end

  test "a browse snapshot cannot combine an old actor cart with a replacement shop" do
    assert {:noreply, prepared} = SkillHandler.handle_use_skill(session(300), 41, 3, 7001)

    request = %VendingOpenRequest{
      request_id: 19,
      setup_id: prepared.vending_setup.setup_id,
      title: "Old",
      entries: [%VendingEntry{cart_index: 0, amount: 3, price: 100}]
    }

    assert {:noreply, opened} = VendingHandler.handle_open(prepared, request)
    replacement = %{opened.game_state.state_context | shop_id: "replacement", title: "New"}
    Registry.put(7001, self(), replacement)

    assert :error = VendingHandler.build_list(7001)
    assert {:ok, ^replacement} = Registry.get(7001)
  end
end
