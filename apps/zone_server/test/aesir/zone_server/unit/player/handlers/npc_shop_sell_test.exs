defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcShopSellTest do
  @moduledoc """
  DataCase coverage for the single-player NPC shop sell (`NpcShopHandler.sell/2`):
  the atomic inventory-removal + zeny-credit transaction, its failure modes, the
  `MAX_ZENY` credit clamp, and the anti-forgery / range gates. The removal path
  runs the real `Unit.Inventory` core and `InventoryOps`; sell prices are stubbed
  through `ItemManagement` (the item DB ships almost no `sell` values, and the
  clamp test needs a huge one), mirroring the pure-core `shop_test`.
  """
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcSellEntry
  alias Aesir.Net.NpcSellRequest
  alias Aesir.Net.NpcSellResult
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @potion 501
  @max_zeny 1_000_000_000

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Shops)
    Mimic.copy(ItemManagement)
    Mimic.copy(InventoryPersistence)
    :ok
  end

  setup do
    %{seller: insert_character("Seller", 1_000)}
  end

  # The shop never lists @potion: selling is not restricted to the shop's buy
  # list, so a sellable inventory item still sells.
  defp shop do
    %Shop{
      id: "prontera_tool_dealer",
      map: "prontera",
      x: 150,
      y: 60,
      dir: 4,
      sprite: 85,
      name: "Tool Dealer",
      items: [%{nameid: 909, price: nil}]
    }
  end

  defp register_shop(shop), do: stub(Shops, :all, fn -> %{"prontera" => [shop]} end)

  defp stub_sell_price(nameid, sell) do
    stub(ItemManagement, :get_item_by_id, fn
      ^nameid ->
        {:ok,
         %ItemDefinition{
           id: nameid,
           aegis_name: "i#{nameid}",
           name: "i#{nameid}",
           type: :healing,
           buy: 10,
           sell: sell,
           weight: 70
         }}

      _other ->
        {:error, :not_found}
    end)
  end

  defp request(shop, entries) do
    %NpcSellRequest{
      unit_id: Shop.Registry.entity_id(shop),
      items:
        Enum.map(entries, fn {index, amount} ->
          %NpcSellEntry{inventory_index: index, amount: amount}
        end)
    }
  end

  describe "sell/2" do
    test "commits the inventory removal and the zeny credit atomically", ctx do
      shop = shop()
      register_shop(shop)
      stub_sell_price(@potion, 25)
      inventory = seed_inventory(ctx.seller.id, 10)

      assert {:noreply, new_state} =
               NpcShopHandler.sell(
                 seller_state(ctx.seller, inventory, 1_000, 150, 60),
                 request(shop, [{0, 4}])
               )

      assert [%InventoryItem{nameid: @potion, amount: 6}] =
               InventoryPersistence.load_inventory(ctx.seller.id)

      assert reload_zeny(ctx.seller.id) == 1_000 + 4 * 25
      assert new_state.game_state.zeny == 1_100

      assert [%InventoryItem{nameid: @potion, amount: 6}] =
               Map.values(new_state.game_state.inventory)

      assert_receive {:send, _ch, {:item_removed, %Aesir.Net.ItemRemoved{amount: 4}}}
      assert_receive {:send, _ch, {:param_change, %Aesir.Net.ParamChange{value: 1_100}}}
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 0}}}
    end

    test "selling the whole stack drops the slot", ctx do
      shop = shop()
      register_shop(shop)
      stub_sell_price(@potion, 25)
      inventory = seed_inventory(ctx.seller.id, 3)

      assert {:noreply, new_state} =
               NpcShopHandler.sell(
                 seller_state(ctx.seller, inventory, 1_000, 150, 60),
                 request(shop, [{0, 3}])
               )

      assert [] = InventoryPersistence.load_inventory(ctx.seller.id)
      assert new_state.game_state.inventory == %{}
      assert reload_zeny(ctx.seller.id) == 1_075
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 0}}}
    end

    test "an unowned slot is rejected and writes nothing", ctx do
      shop = shop()
      register_shop(shop)

      {:noreply, _} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, %{}, 1_000, 150, 60),
          request(shop, [{7, 1}])
        )

      assert [] = InventoryPersistence.load_inventory(ctx.seller.id)
      assert reload_zeny(ctx.seller.id) == 1_000
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 4}}}
    end

    test "an insufficient amount is rejected and writes nothing", ctx do
      shop = shop()
      register_shop(shop)
      inventory = seed_inventory(ctx.seller.id, 2)

      {:noreply, _} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, inventory, 1_000, 150, 60),
          request(shop, [{0, 5}])
        )

      assert [%InventoryItem{amount: 2}] =
               InventoryPersistence.load_inventory(ctx.seller.id)

      assert reload_zeny(ctx.seller.id) == 1_000
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 4}}}
    end

    test "an unsellable item (sell == 0) is rejected and writes nothing", ctx do
      shop = shop()
      register_shop(shop)
      # No stub: the real item 501 ships no sell value (defaults to 0).
      inventory = seed_inventory(ctx.seller.id, 3)

      {:noreply, _} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, inventory, 1_000, 150, 60),
          request(shop, [{0, 1}])
        )

      assert [%InventoryItem{amount: 3}] =
               InventoryPersistence.load_inventory(ctx.seller.id)

      assert reload_zeny(ctx.seller.id) == 1_000
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 4}}}
    end

    test "the credit clamps at MAX_ZENY", ctx do
      shop = shop()
      register_shop(shop)
      stub_sell_price(@potion, 2_000_000_000)
      inventory = seed_inventory(ctx.seller.id, 1)

      {:noreply, new_state} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, inventory, 1_000, 150, 60),
          request(shop, [{0, 1}])
        )

      assert reload_zeny(ctx.seller.id) == @max_zeny
      assert new_state.game_state.zeny == @max_zeny
      assert_receive {:send, _ch, {:param_change, %Aesir.Net.ParamChange{value: @max_zeny}}}
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 0}}}
    end

    test "selling is not restricted to the shop's item list", ctx do
      shop = shop()
      register_shop(shop)
      stub_sell_price(@potion, 25)
      inventory = seed_inventory(ctx.seller.id, 1)

      # @potion is absent from the shop's item list (only 909), yet it sells.
      refute Enum.any?(shop.items, &(&1.nameid == @potion))

      {:noreply, _} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, inventory, 1_000, 150, 60),
          request(shop, [{0, 1}])
        )

      assert [] = InventoryPersistence.load_inventory(ctx.seller.id)
      assert reload_zeny(ctx.seller.id) == 1_025
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 0}}}
    end

    test "a forged/unknown unit_id is rejected without a transaction", ctx do
      shop = shop()
      stub(Shops, :all, fn -> %{} end)
      inventory = seed_inventory(ctx.seller.id, 3)

      {:noreply, _} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, inventory, 1_000, 150, 60),
          request(shop, [{0, 1}])
        )

      assert [%InventoryItem{amount: 3}] =
               InventoryPersistence.load_inventory(ctx.seller.id)

      assert reload_zeny(ctx.seller.id) == 1_000
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 4}}}
    end

    test "a forced removal failure rolls back the whole sell", ctx do
      shop = shop()
      register_shop(shop)

      stub(ItemManagement, :get_item_by_id, fn id ->
        {:ok,
         %ItemDefinition{
           id: id,
           aegis_name: "i#{id}",
           name: "i#{id}",
           type: :healing,
           buy: 10,
           sell: 25,
           weight: 70
         }}
      end)

      # Two slots: a partial reduction (real `update_item`) on index 0 followed by
      # a full removal (`delete_item`, forced to fail) on index 1. The whole
      # `Repo.transact` must roll back, leaving both slots and the zeny untouched.
      {:ok, _} = InventoryPersistence.insert_item(ctx.seller.id, %{nameid: @potion, amount: 5})
      {:ok, _} = InventoryPersistence.insert_item(ctx.seller.id, %{nameid: 502, amount: 3})
      items = InventoryPersistence.load_inventory(ctx.seller.id)
      inventory = PlayerState.from_list(items)

      stub(InventoryPersistence, :delete_item, fn _item -> {:error, :forced_failure} end)

      {:noreply, _} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, inventory, 1_000, 150, 60),
          request(shop, [{0, 2}, {1, 3}])
        )

      loaded = InventoryPersistence.load_inventory(ctx.seller.id)
      assert [3, 5] = loaded |> Enum.map(& &1.amount) |> Enum.sort()
      assert reload_zeny(ctx.seller.id) == 1_000
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 4}}}
    end

    test "an out-of-range sell is rejected without a transaction", ctx do
      shop = shop()
      register_shop(shop)
      inventory = seed_inventory(ctx.seller.id, 3)

      {:noreply, _} =
        NpcShopHandler.sell(
          seller_state(ctx.seller, inventory, 1_000, 10, 10),
          request(shop, [{0, 1}])
        )

      assert [%InventoryItem{amount: 3}] =
               InventoryPersistence.load_inventory(ctx.seller.id)

      assert reload_zeny(ctx.seller.id) == 1_000
      assert_receive {:send, _ch, {:npc_sell_result, %NpcSellResult{result: 5}}}
    end
  end

  defp seller_state(character, inventory, zeny, x, y) do
    base = PlayerState.new(character)

    game_state = %{base | inventory: inventory, zeny: zeny, map_name: "prontera", x: x, y: y}
    %{connection_pid: self(), game_state: game_state}
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

  defp seed_inventory(char_id, amount) do
    {:ok, _} = InventoryPersistence.insert_item(char_id, %{nameid: @potion, amount: amount})
    items = InventoryPersistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp reload_zeny(char_id), do: Repo.get!(Character, char_id).zeny
end
