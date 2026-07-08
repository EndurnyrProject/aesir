defmodule Aesir.ZoneServer.Unit.ShopTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.Shop`.

  No DB, no sockets. Item definitions are stubbed through `ItemManagement` (the
  DB ships almost no `sell` values, and the clamp test needs a huge one), while
  inventory maps and `%Stats{}` are built as real structs. `would_exceed?/3`
  relies on the real novice job base (`20_000`) loaded at app boot.
  """
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Npc.Shop, as: ShopData
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Shop
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  @red_potion 501
  @orange_potion 502
  @sword 1101
  @jellopy 909
  @worthless 910
  @priceless 9999
  @novice 0

  @defs %{
    @red_potion => %{type: :healing, buy: 50, sell: 25, weight: 70},
    @orange_potion => %{type: :healing, buy: 100, sell: 40, weight: 100},
    @sword => %{type: :weapon, buy: 100, sell: 50, weight: 500},
    @jellopy => %{type: :etc, buy: 6, sell: 0, weight: 1},
    @worthless => %{type: :etc, buy: 0, sell: 0, weight: 1},
    @priceless => %{type: :etc, buy: 1, sell: 2_000_000_000, weight: 1}
  }

  setup :verify_on_exit!

  setup do
    stub(ItemManagement, :get_item_by_id, fn id ->
      case Map.fetch(@defs, id) do
        {:ok, attrs} -> {:ok, item_def(id, attrs)}
        :error -> {:ok, item_def(id, %{type: :etc, buy: 1, sell: 0, weight: 1})}
      end
    end)

    :ok
  end

  defp item_def(id, attrs) do
    struct!(ItemDefinition, Map.merge(%{id: id, aegis_name: "I#{id}", name: "I#{id}"}, attrs))
  end

  defp item(attrs) do
    base = %{
      id: System.unique_integer([:positive]),
      char_id: 1,
      nameid: @red_potion,
      amount: 1,
      equip: 0,
      identify: 1,
      refine: 0,
      attribute: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      random_options: %{},
      bound: 0,
      favorite: 0
    }

    struct(InventoryItem, Map.merge(base, Map.new(attrs)))
  end

  defp inventory(items), do: PlayerState.from_list(items)

  defp stats(str) do
    %Stats{
      base_stats: %BaseStats{str: str, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      progression: %PlayerProgression{job_id: @novice},
      modifiers: %Modifiers{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
    }
  end

  defp player(attrs) do
    base = %{zeny: 1_000_000, inventory: %{}, stats: stats(1)}
    struct(PlayerState, Map.merge(base, Map.new(attrs)))
  end

  # Tool Dealer: 501 has a per-shop override (50), 502 and the sword fall back to
  # ItemDefinition.buy.
  defp shop do
    %ShopData{
      id: "tool_dealer",
      map: "prontera",
      x: 150,
      y: 60,
      dir: 4,
      sprite: 85,
      name: "Tool Dealer",
      items: [
        %{nameid: @red_potion, price: 50},
        %{nameid: @orange_potion, price: nil},
        %{nameid: @sword, price: nil}
      ]
    }
  end

  describe "effective prices" do
    test "buy uses the per-item override when present" do
      assert Shop.effective_buy_price(shop(), @red_potion) == 50
    end

    test "buy falls back to ItemDefinition.buy when no override" do
      assert Shop.effective_buy_price(shop(), @orange_potion) == 100
    end

    test "sell resolves ItemDefinition.sell" do
      assert Shop.effective_sell_price(@red_potion) == 25
    end
  end

  describe "compute_buy/3" do
    test "sums cost using the override and the base buy price" do
      assert {:ok, %{total_cost: 200, item_adds: adds}} =
               Shop.compute_buy(shop(), [{@red_potion, 2}, {@orange_potion, 1}], player(%{}))

      assert [{%ItemDefinition{id: @red_potion}, 2}, {%ItemDefinition{id: @orange_potion}, 1}] =
               adds
    end

    test "rejects a nameid not on the shop's list" do
      assert {:error, :item_not_in_shop} =
               Shop.compute_buy(shop(), [{@jellopy, 1}], player(%{}))
    end

    test "rejects when the player cannot afford the total" do
      assert {:error, :not_enough_zeny} =
               Shop.compute_buy(shop(), [{@red_potion, 1}], player(%{zeny: 10}))
    end

    test "rejects when the buy would push the player overweight" do
      # novice str 1 -> max 20_300; 41 swords at weight 500 = 20_500 > 20_300.
      assert {:error, :overweight} =
               Shop.compute_buy(shop(), [{@sword, 41}], player(%{zeny: 1_000_000}))
    end

    test "rejects when there is no free inventory slot for a new item" do
      fillers = for i <- 0..99, do: item(nameid: 1000 + i, amount: 1)

      assert {:error, :no_slots} =
               Shop.compute_buy(
                 shop(),
                 [{@red_potion, 1}],
                 player(%{inventory: inventory(fillers)})
               )
    end
  end

  describe "compute_sell/2" do
    test "sums credit from ItemDefinition.sell and returns the removals" do
      inv = inventory([item(nameid: @red_potion, amount: 5), item(nameid: @sword, amount: 1)])

      assert {:ok, %{total_credit: 100, removals: [{0, 2}, {1, 1}]}} =
               Shop.compute_sell([{0, 2}, {1, 1}], player(%{inventory: inv}))
    end

    test "clamps the total credit to MAX_ZENY" do
      inv = inventory([item(nameid: @priceless, amount: 2)])

      assert {:ok, %{total_credit: 1_000_000_000}} =
               Shop.compute_sell([{0, 2}], player(%{inventory: inv}))
    end

    test "rejects an unowned inventory slot" do
      assert {:error, :invalid_item} =
               Shop.compute_sell([{7, 1}], player(%{inventory: %{}}))
    end

    test "rejects when the slot holds fewer than requested" do
      inv = inventory([item(nameid: @red_potion, amount: 1)])

      assert {:error, :insufficient_amount} =
               Shop.compute_sell([{0, 5}], player(%{inventory: inv}))
    end

    test "rejects an item with no value (buy and sell both 0)" do
      inv = inventory([item(nameid: @worthless, amount: 3)])

      assert {:error, :unsellable} =
               Shop.compute_sell([{0, 1}], player(%{inventory: inv}))
    end

    test "sells an item with sell == 0 at the Buy / 2 fallback" do
      inv = inventory([item(nameid: @jellopy, amount: 3)])

      assert {:ok, %{total_credit: 3, removals: [{0, 1}]}} =
               Shop.compute_sell([{0, 1}], player(%{inventory: inv}))
    end

    test "rejects a bound item even when sellable by price" do
      inv = inventory([item(nameid: @red_potion, amount: 3, bound: 1)])

      assert {:error, :unsellable} =
               Shop.compute_sell([{0, 1}], player(%{inventory: inv}))
    end

    test "rejects an equipped item even when sellable by price" do
      inv = inventory([item(nameid: @sword, amount: 1, equip: 2)])

      assert {:error, :unsellable} =
               Shop.compute_sell([{0, 1}], player(%{inventory: inv}))
    end

    test "is not restricted to the shop's item list" do
      inv = inventory([item(nameid: @sword, amount: 1)])

      assert {:ok, %{total_credit: 50}} = Shop.compute_sell([{0, 1}], player(%{inventory: inv}))
    end
  end

  describe "build_open/2" do
    test "buy list comes from the shop with resolved prices and client types" do
      {buy_items, _sell_items} = Shop.build_open(shop(), player(%{}))

      assert buy_items == [
               %{nameid: @red_potion, type: 0, price: 50},
               %{nameid: @orange_potion, type: 0, price: 100},
               %{nameid: @sword, type: 5, price: 100}
             ]
    end

    test "sell list is the player's sellable inventory, dropping unsellables" do
      inv =
        inventory([
          item(nameid: @red_potion, amount: 3),
          item(nameid: @worthless, amount: 1),
          item(nameid: @sword, amount: 1, favorite: 1),
          item(nameid: @orange_potion, amount: 1, equip: 2)
        ])

      {_buy_items, sell_items} = Shop.build_open(shop(), player(%{inventory: inv}))

      assert sell_items == [
               %{inventory_index: 0, nameid: @red_potion, type: 0, amount: 3, sell_price: 25}
             ]
    end
  end

  describe "purity" do
    test "the source carries no Repo, socket, or GenServer dependency" do
      path = Shop.module_info(:compile)[:source]
      source = File.read!(path)

      refute source =~ ~r/\b(Repo|Socket|GenServer|persistent_term)\b/
    end
  end
end
