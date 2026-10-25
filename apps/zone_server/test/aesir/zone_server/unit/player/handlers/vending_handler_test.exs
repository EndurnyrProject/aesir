defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Auth
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemOption
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingShopItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending.Registry
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 7001
  @vending_level 3

  setup do
    test_pid = self()

    stub(SpatialIndex, :get_unit_position, fn :player, @char_id ->
      {:ok, {150, 150, "prontera"}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
      send(test_pid, {:board, packet})
      :ok
    end)

    stub(Auth, :get_account!, fn 2000 -> %Account{id: 2000, group_id: 0} end)

    stub(Broadcast, :to_player, fn @char_id, packet ->
      send(test_pid, {:to_player, packet})
      :ok
    end)

    stub(NpcRegistry, :entries, fn -> [] end)
    stub(Warps, :for_map, fn _map -> :error end)
    stub(Shops, :for_map, fn _map -> :error end)

    :ok
  end

  defp vending_id do
    {:ok, definition} = Catalog.by_name(:mc_vending)
    definition.id
  end

  defp character(opts) do
    %Character{
      id: @char_id,
      account_id: 2000,
      name: "Merchy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 50,
      class: 0,
      hp: 800,
      sp: Keyword.get(opts, :sp, 300),
      learned_skills: Keyword.get(opts, :learned_skills, %{})
    }
  end

  defp item(nameid, amount, opts \\ []) do
    %InventoryItem{
      id: 11,
      char_id: @char_id,
      nameid: nameid,
      amount: amount,
      identify: Keyword.get(opts, :identify, 1),
      bound: Keyword.get(opts, :bound, 0),
      craft: Keyword.get(opts, :craft),
      random_options: Keyword.get(opts, :random_options, [])
    }
  end

  defp state(opts) do
    base = PlayerState.new(character(opts))
    mounted = StatusStorage.has_status?(:player, @char_id, :sc_push_cart)

    game_state = %{
      base
      | cart: Keyword.get(opts, :cart_map, %{0 => item(501, 10)}),
        cart_type: if(mounted, do: 1, else: 0)
    }

    :ok = UnitRegistry.register_player(game_state, self())
    prepared = Keyword.get(opts, :prepared, true)

    grant =
      if prepared, do: %{setup_id: "paid-fixture", level: @vending_level, sp_spent: 30}, else: nil

    %SessionState{
      connection_pid: self(),
      game_state: game_state,
      vending_setup: grant,
      work_in_progress: prepared
    }
  end

  defp submit(state, title, entries) do
    request = %VendingOpenRequest{
      request_id: 1,
      setup_id: state.vending_setup.setup_id,
      title: title,
      entries:
        Enum.map(entries, fn {index, amount, price} ->
          %VendingEntry{cart_index: index, amount: amount, price: price}
        end)
    }

    VendingHandler.handle_open(state, request)
  end

  defp learned(level), do: %{Integer.to_string(vending_id()) => level}

  defp mount_cart do
    StatusStorage.apply_status(:player, @char_id, :sc_push_cart, val1: 1, val2: 1)
  end

  describe "open_shop/3" do
    test "opening consumes an already-paid grant without charging SP again" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level))

      assert {:ok, new_state} = VendingHandler.open_shop(base, "Cheap Pots", [{0, 5, 100}])

      assert new_state.game_state.stats.current_state.sp == base.game_state.stats.current_state.sp
    end

    test "an invalid state transition leaves SP untouched" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level))
      vending = %{base | game_state: %{base.game_state | action_state: :moving}}

      assert {:error, :invalid_transition} =
               VendingHandler.open_shop(vending, "Shop", [{0, 5, 100}])

      assert vending.game_state.stats.current_state.sp == 300
    end

    test "a paid grant can open with less than the skill cost remaining" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level), sp: 29)

      assert {:ok, opened} = VendingHandler.open_shop(base, "Shop", [{0, 5, 100}])
      assert opened.game_state.stats.current_state.sp == 29
      assert {:ok, _shop} = Registry.get(@char_id)
    end

    test "with a mounted cart and MC_VENDING learned enters :vending, registers, broadcasts" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level))

      assert {:ok, new_state} = VendingHandler.open_shop(base, "Cheap Pots", [{0, 5, 100}])

      assert new_state.game_state.action_state == :vending

      assert {:ok, shop} = Registry.get(@char_id)
      assert shop.title == "Cheap Pots"
      assert [%ShopItem{cart_index: 0, nameid: 501, amount: 5, price: 100}] = shop.items

      assert_received {:board, %VendingBoardShown{unit_id: @char_id, title: "Cheap Pots"}}
    end

    test "without a mounted cart returns an error and changes nothing" do
      base = state(learned_skills: learned(@vending_level))

      assert {:error, :no_cart} = VendingHandler.open_shop(base, "Shop", [{0, 5, 100}])

      assert :error = Registry.get(@char_id)
      refute_received {:board, _}

      vending = %{
        base
        | game_state: %{base.game_state | action_state: :vending},
          vending_setup: nil,
          work_in_progress: false
      }

      assert {:noreply, ^vending} =
               SkillHandler.handle_use_skill(vending, 41, @vending_level, @char_id)

      refute_received {:to_player, %SkillCastFailed{}}
    end

    test "without MC_VENDING learned returns an error and changes nothing" do
      mount_cart()
      base = state(learned_skills: %{})

      assert {:error, :skill_not_learned} = VendingHandler.open_shop(base, "Shop", [{0, 5, 100}])

      assert :error = Registry.get(@char_id)
      refute_received {:board, _}
    end

    test "rejects an unidentified selected cart item without opening the shop" do
      mount_cart()

      base =
        state(
          learned_skills: learned(@vending_level),
          cart_map: %{0 => item(1101, 1, identify: 0)}
        )

      assert {:error, :item_unidentified} = VendingHandler.open_shop(base, "Shop", [{0, 1, 100}])

      assert :error = Registry.get(@char_id)
      refute_received {:board, _}
    end
  end

  describe "activation and handle_open/2" do
    test "an NPC within three cells refuses activation before anything is spent" do
      mount_cart()
      npc = %Placement{map: "prontera", x: 153, y: 147, sprite: 1, name: "n", unique_name: "n"}
      stub(NpcRegistry, :entries, fn -> [{__MODULE__, npc}] end)
      base = state(learned_skills: learned(@vending_level), prepared: false)

      assert {:noreply, ^base} = SkillHandler.handle_use_skill(base, 41, @vending_level, @char_id)

      assert_received {:to_player,
                       %SkillCastFailed{
                         skill_id: 41,
                         reason: :SKILL_CAST_FAILURE_REASON_NPC_NEARBY
                       }}

      assert :error = Registry.get(@char_id)
      refute_received {:board, _}
      refute_received {:send, :world, {:vending_setup_ready, _}}
    end

    test "activation reports insufficient SP without offering preparation" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level), sp: 10, prepared: false)
      assert {:noreply, ^base} = SkillHandler.handle_use_skill(base, 41, @vending_level, @char_id)

      assert_received {:to_player,
                       %SkillCastFailed{
                         skill_id: 41,
                         reason: :SKILL_CAST_FAILURE_REASON_INSUFFICIENT_SP
                       }}

      refute_received {:send, :world, {:vending_setup_ready, _}}
    end

    test "confirms a successful paid-grant submission" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level))
      assert {:noreply, opened} = submit(base, "Cheap Pots", [{0, 5, 100}])
      assert opened.vending_setup == nil

      assert_received {:send, :world,
                       {:vending_open_result,
                        %Aesir.Net.VendingOpenResult{request_id: 1, result: :VEND_OK}}}
    end

    test "reports missing skill and ends the rejected setup" do
      mount_cart()
      base = state(learned_skills: %{})
      assert {:noreply, refused} = submit(base, "Shop", [{0, 5, 100}])
      assert refused.vending_setup == nil
      assert refused.game_state == base.game_state

      assert_received {:send, :world,
                       {:vending_open_result,
                        %Aesir.Net.VendingOpenResult{
                          result: :VEND_SKILL_NOT_LEARNED,
                          setup_active: false
                        }}}
    end

    test "reports a lost cart and ends the rejected setup" do
      base = state(learned_skills: learned(@vending_level))
      assert {:noreply, refused} = submit(base, "Shop", [{0, 5, 100}])
      assert refused.vending_setup == nil
      assert refused.game_state == base.game_state

      assert_received {:send, :world,
                       {:vending_open_result,
                        %Aesir.Net.VendingOpenResult{result: :VEND_NO_CART, setup_active: false}}}
    end

    test "reports an unidentified selected item without opening or refunding" do
      mount_cart()

      base =
        state(
          learned_skills: learned(@vending_level),
          cart_map: %{0 => item(1101, 1, identify: 0)}
        )

      assert {:noreply, refused} = submit(base, "Shop", [{0, 1, 100}])
      assert refused.vending_setup == nil
      assert refused.game_state == base.game_state

      assert_received {:send, :world,
                       {:vending_open_result,
                        %Aesir.Net.VendingOpenResult{
                          result: :VEND_ITEM_UNIDENTIFIED,
                          setup_active: false
                        }}}
    end

    test "reports a bound selected item without opening or refunding" do
      mount_cart()

      base =
        state(learned_skills: learned(@vending_level), cart_map: %{0 => item(1101, 1, bound: 1)})

      assert {:noreply, refused} = submit(base, "Shop", [{0, 1, 100}])
      assert refused.vending_setup == nil
      assert refused.game_state == base.game_state

      assert_received {:send, :world,
                       {:vending_open_result,
                        %Aesir.Net.VendingOpenResult{
                          result: :VEND_ITEM_BOUND,
                          setup_active: false
                        }}}
    end

    test "rejects opening more lines than max_slots for the learned level" do
      mount_cart()
      cart = Map.new(0..(@vending_level + 2), fn i -> {i, item(501 + i, 5)} end)
      base = state(learned_skills: learned(1), cart_map: cart)
      entries = Enum.map(0..3, fn i -> {i, 1, 100} end)
      assert {:error, :too_many_slots} = VendingHandler.open_shop(base, "Shop", entries)
      assert :error = Registry.get(@char_id)
    end
  end

  describe "close_shop/2" do
    test "removes the registry entry, broadcasts removal, returns to :idle, leaves cart intact" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level))
      {:ok, opened} = VendingHandler.open_shop(base, "Cheap Pots", [{0, 5, 100}])

      assert {:ok, closed} = VendingHandler.close_shop(opened, :manual)

      assert closed.game_state.action_state == :idle
      assert closed.game_state.cart == opened.game_state.cart
      assert :error = Registry.get(@char_id)
      assert_received {:board, %VendingBoardRemoved{unit_id: @char_id}}
    end

    test "is a safe no-op when the session is not vending" do
      base = state(learned_skills: %{}, prepared: false)

      assert {:ok, ^base} = VendingHandler.close_shop(base, :disconnected)
      refute_received {:board, _}
    end
  end

  describe "build_list/1" do
    test "returns the current VendingList for an open vendor" do
      mount_cart()
      base = state(learned_skills: learned(@vending_level))
      {:ok, opened} = VendingHandler.open_shop(base, "Cheap Pots", [{0, 5, 100}])
      UnitRegistry.register_player(opened.game_state, self())

      assert {:ok, %VendingList{vendor_unit_id: @char_id, title: "Cheap Pots", items: items}} =
               VendingHandler.build_list(@char_id)

      assert [%VendingShopItem{index: 0, nameid: 501, amount: 5, price: 100}] = items
    end

    test "includes a signed item's creator metadata" do
      mount_cart()
      signed = item(501, 10, craft: ItemCraft.to_map(ItemCraft.signed(10)))
      base = state(learned_skills: learned(@vending_level), cart_map: %{0 => signed})
      {:ok, opened} = VendingHandler.open_shop(base, "Cheap Pots", [{0, 5, 100}])
      UnitRegistry.register_player(opened.game_state, self())
      expect(Repo, :all, fn _query -> [{10, "Signer"}] end)

      assert {:ok, %VendingList{items: [shop_item]}} = VendingHandler.build_list(@char_id)
      assert %VendingShopItem{} = shop_item
      assert shop_item.creator_kind == :CREATOR_SIGNED
      assert shop_item.creator_id == 10
      assert shop_item.signer_name == "Signer"
    end

    test "includes the item's random options" do
      mount_cart()
      optioned = item(501, 10, random_options: [%{id: 3, value: 5, param: 0}])
      base = state(learned_skills: learned(@vending_level), cart_map: %{0 => optioned})
      {:ok, opened} = VendingHandler.open_shop(base, "Cheap Pots", [{0, 5, 100}])
      UnitRegistry.register_player(opened.game_state, self())

      assert {:ok, %VendingList{items: [shop_item]}} = VendingHandler.build_list(@char_id)
      assert shop_item.options == [%ItemOption{id: 3, value: 5, param: 0}]
    end

    test "returns :error for a vendor with no open shop" do
      assert :error = VendingHandler.build_list(@char_id)
    end
  end
end
