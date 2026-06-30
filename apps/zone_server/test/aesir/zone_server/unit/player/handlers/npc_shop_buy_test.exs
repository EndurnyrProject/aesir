defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcShopBuyTest do
  @moduledoc """
  DataCase coverage for the single-player NPC shop buy (`NpcShopHandler.buy/2`):
  the atomic inventory-add + zeny-debit transaction, its failure modes, and the
  anti-forgery / range gates. The happy path exercises the real pure `Unit.Shop`
  core and `ItemManagement` lookups; the compute-error cases stub the core to
  pin the handler's result-code mapping and the no-transaction-on-error contract.
  """
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcBuyEntry
  alias Aesir.Net.NpcBuyRequest
  alias Aesir.Net.NpcBuyResult
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcShopHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Shop, as: ShopCore

  @potion 501
  @price 50

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Shops)
    Mimic.copy(ShopCore)
    Mimic.copy(InventoryPersistence)
    :ok
  end

  setup do
    %{buyer: insert_character("Buyer", 1_000)}
  end

  defp shop do
    %Shop{
      id: "prontera_tool_dealer",
      map: "prontera",
      x: 150,
      y: 60,
      dir: 4,
      sprite: 85,
      name: "Tool Dealer",
      items: [%{nameid: @potion, price: @price}]
    }
  end

  defp register_shop(shop), do: stub(Shops, :all, fn -> %{"prontera" => [shop]} end)

  defp request(shop, entries) do
    %NpcBuyRequest{
      unit_id: Shop.Registry.entity_id(shop),
      items:
        Enum.map(entries, fn {nameid, amount} -> %NpcBuyEntry{nameid: nameid, amount: amount} end)
    }
  end

  describe "buy/2" do
    test "commits inventory adds and the zeny debit atomically", ctx do
      shop = shop()
      register_shop(shop)

      assert {:noreply, new_state} =
               NpcShopHandler.buy(
                 buyer_state(ctx.buyer, %{}, 1_000, 150, 60),
                 request(shop, [{@potion, 4}])
               )

      assert [%InventoryItem{nameid: @potion, amount: 4}] =
               InventoryPersistence.load_inventory(ctx.buyer.id)

      assert reload_zeny(ctx.buyer.id) == 1_000 - 4 * @price
      assert new_state.game_state.zeny == 1_000 - 4 * @price

      assert [%InventoryItem{nameid: @potion, amount: 4}] =
               Map.values(new_state.game_state.inventory)

      assert_receive {:send, _ch, {:item_added, %Aesir.Net.ItemAdded{nameid: @potion, amount: 4}}}
      assert_receive {:send, _ch, {:param_change, %Aesir.Net.ParamChange{value: 800}}}
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 0}}}
    end

    test "insufficient zeny is rejected and writes nothing", ctx do
      shop = shop()
      register_shop(shop)

      # In-memory zeny 10 trips the gate; the persisted row (1_000) stays untouched.
      {:noreply, _} =
        NpcShopHandler.buy(
          buyer_state(ctx.buyer, %{}, 10, 150, 60),
          request(shop, [{@potion, 4}])
        )

      assert [] = InventoryPersistence.load_inventory(ctx.buyer.id)
      assert reload_zeny(ctx.buyer.id) == 1_000
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 1}}}
    end

    test "overweight is rejected and writes nothing", ctx do
      shop = shop()
      register_shop(shop)
      stats = Stats.from_character(ctx.buyer)
      fill = div(Weight.max_weight(stats), 70)
      seed_inventory(ctx.buyer.id, fill)
      inventory = load_inventory_map(ctx.buyer.id)

      {:noreply, _} =
        NpcShopHandler.buy(
          buyer_state(ctx.buyer, inventory, 1_000, 150, 60),
          request(shop, [{@potion, 1}])
        )

      assert [%InventoryItem{amount: ^fill}] =
               InventoryPersistence.load_inventory(ctx.buyer.id)

      assert reload_zeny(ctx.buyer.id) == 1_000
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 2}}}
    end

    test "no free slots is rejected and writes nothing", ctx do
      shop = shop()
      register_shop(shop)
      stub(ShopCore, :compute_buy, fn ^shop, _req, _gs -> {:error, :no_slots} end)

      {:noreply, _} =
        NpcShopHandler.buy(
          buyer_state(ctx.buyer, %{}, 1_000, 150, 60),
          request(shop, [{@potion, 1}])
        )

      assert [] = InventoryPersistence.load_inventory(ctx.buyer.id)
      assert reload_zeny(ctx.buyer.id) == 1_000
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 3}}}
    end

    test "an item not in the shop is rejected and writes nothing", ctx do
      shop = shop()
      register_shop(shop)

      {:noreply, _} =
        NpcShopHandler.buy(buyer_state(ctx.buyer, %{}, 1_000, 150, 60), request(shop, [{909, 1}]))

      assert [] = InventoryPersistence.load_inventory(ctx.buyer.id)
      assert reload_zeny(ctx.buyer.id) == 1_000
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 4}}}
    end

    test "a forged/unknown unit_id is rejected without a transaction", ctx do
      shop = shop()
      stub(Shops, :all, fn -> %{} end)

      {:noreply, _} =
        NpcShopHandler.buy(
          buyer_state(ctx.buyer, %{}, 1_000, 150, 60),
          request(shop, [{@potion, 1}])
        )

      assert [] = InventoryPersistence.load_inventory(ctx.buyer.id)
      assert reload_zeny(ctx.buyer.id) == 1_000
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 4}}}
    end

    test "an out-of-range buy is rejected without a transaction", ctx do
      shop = shop()
      register_shop(shop)

      {:noreply, _} =
        NpcShopHandler.buy(
          buyer_state(ctx.buyer, %{}, 1_000, 10, 10),
          request(shop, [{@potion, 1}])
        )

      assert [] = InventoryPersistence.load_inventory(ctx.buyer.id)
      assert reload_zeny(ctx.buyer.id) == 1_000
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 5}}}
    end

    test "a forced insert failure rolls back the whole buy", ctx do
      shop = shop()
      register_shop(shop)

      stub(InventoryPersistence, :insert_item, fn _char_id, _attrs ->
        {:error, :forced_failure}
      end)

      {:noreply, _} =
        NpcShopHandler.buy(
          buyer_state(ctx.buyer, %{}, 1_000, 150, 60),
          request(shop, [{@potion, 4}])
        )

      assert [] = InventoryPersistence.load_inventory(ctx.buyer.id)
      assert reload_zeny(ctx.buyer.id) == 1_000
      assert_receive {:send, _ch, {:npc_buy_result, %NpcBuyResult{result: 4}}}
    end
  end

  defp buyer_state(character, inventory, zeny, x, y) do
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
    :ok
  end

  defp load_inventory_map(char_id) do
    items = InventoryPersistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp reload_zeny(char_id), do: Repo.get!(Character, char_id).zeny
end
