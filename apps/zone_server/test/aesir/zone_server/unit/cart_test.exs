defmodule Aesir.ZoneServer.Unit.CartTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.Cart`.

  No DB, no sockets: cart maps are built with real `%InventoryItem{}` structs
  via `PlayerState.from_list/1` and item definitions come from `priv/db/re/items/`
  resolved through `ItemManagement.get_item_by_id/1`. The cart reuses the pure
  `Inventory` storage core, so these mirror the inventory core tests.
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @red_potion 501
  @sword 1101

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
      random_options: %{}
    }

    struct(InventoryItem, Map.merge(base, Map.new(attrs)))
  end

  defp cart(items), do: PlayerState.from_list(items)

  defp def!(id) do
    {:ok, d} = ItemManagement.get_item_by_id(id)
    d
  end

  describe "add/4" do
    test "adds a new item to an empty cart at the lowest free index" do
      def_ = def!(@sword)

      assert {:ok, c, {:added, 0, %InventoryItem{nameid: @sword, amount: 1}}} =
               Cart.add(%{}, def_, 1)

      assert %{0 => %InventoryItem{nameid: @sword}} = c
    end

    test "stacks into an existing stackable item of the same nameid" do
      def_ = def!(@red_potion)
      c = cart([item(nameid: @red_potion, amount: 5)])

      assert {:ok, new_c, {:stacked, 0, 8}} = Cart.add(c, def_, 3)
      assert %{0 => %InventoryItem{amount: 8}} = new_c
    end

    test "overflow past max stack tops the existing stack and splits the remainder" do
      def_ = def!(@red_potion)
      c = cart([item(nameid: @red_potion, amount: 29_999)])

      assert {:ok, new_c, {:split, splits}} = Cart.add(c, def_, 5)
      assert splits == [{0, 30_000}, {1, 4}]
      assert %{0 => %InventoryItem{amount: 30_000}, 1 => %InventoryItem{amount: 4}} = new_c
    end

    test "rejects with :inventory_full when the 100-slot cap is reached" do
      def_ = def!(@sword)
      full = cart(for n <- 1..100, do: item(nameid: 600 + n, amount: 1))

      assert {:error, :inventory_full} = Cart.add(full, def_, 1)
    end
  end

  describe "remove/3" do
    test "reduces the amount when removing fewer than held" do
      c = cart([item(nameid: @red_potion, amount: 10)])

      assert {:ok, new_c, {:reduced, 0, 7}} = Cart.remove(c, 0, 3)
      assert %{0 => %InventoryItem{amount: 7}} = new_c
    end

    test "removes the slot when the amount hits zero" do
      c = cart([item(nameid: @red_potion, amount: 3)])

      assert {:ok, new_c, {:removed, 0}} = Cart.remove(c, 0, 3)
      assert new_c == %{}
    end

    test "returns :insufficient_amount when removing more than held" do
      c = cart([item(nameid: @red_potion, amount: 2)])

      assert {:error, :insufficient_amount} = Cart.remove(c, 0, 5)
    end
  end

  describe "held_amount/2 and stackable_index/2" do
    test "held_amount sums stackable stacks of the nameid" do
      c = cart([item(nameid: @red_potion, amount: 5), item(nameid: @red_potion, amount: 7)])

      assert Cart.held_amount(c, @red_potion) == 12
    end

    test "stackable_index returns the index of a stackable slot, nil when none" do
      c = cart([item(nameid: @red_potion, amount: 5)])

      assert Cart.stackable_index(c, @red_potion) == 0
      assert Cart.stackable_index(c, @sword) == nil
    end
  end
end
