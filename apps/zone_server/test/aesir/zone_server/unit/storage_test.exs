defmodule Aesir.ZoneServer.Unit.StorageTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.Storage`.

  No DB, no sockets: storage maps are built with real `%InventoryItem{}`
  structs via `PlayerState.from_list/1` and item definitions come from
  `priv/db/re/items/` resolved through `ItemManagement.get_item_by_id/1`.
  Storage reuses the pure `ItemContainer` core, so these mirror the cart core
  tests aside from the `storable?/1` policy check.
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Storage

  @red_potion 501
  @sword 1101

  defp item(attrs) do
    base = %{
      id: System.unique_integer([:positive]),
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
      bound: 0
    }

    struct(InventoryItem, Map.merge(base, Map.new(attrs)))
  end

  defp storage(items), do: PlayerState.from_list(items)

  defp def!(id) do
    {:ok, d} = ItemManagement.get_item_by_id(id)
    d
  end

  describe "capacity/0" do
    test "returns 600" do
      assert Storage.capacity() == 600
    end
  end

  describe "add/4" do
    test "adds a new item to an empty storage at the lowest free index" do
      def_ = def!(@sword)

      assert {:ok, s, {:added, 0, %InventoryItem{nameid: @sword, amount: 1}}} =
               Storage.add(%{}, def_, 1)

      assert %{0 => %InventoryItem{nameid: @sword}} = s
    end

    test "stacks into an existing stackable item of the same nameid" do
      def_ = def!(@red_potion)
      s = storage([item(nameid: @red_potion, amount: 5)])

      assert {:ok, new_s, {:stacked, 0, 8}} = Storage.add(s, def_, 3)
      assert %{0 => %InventoryItem{amount: 8}} = new_s
    end

    test "rejects with :inventory_full when the 600-slot cap is reached" do
      def_ = def!(@sword)
      full = storage(for n <- 1..600, do: item(nameid: 600_000 + n, amount: 1))

      assert {:error, :inventory_full} = Storage.add(full, def_, 1)
    end
  end

  describe "remove/3" do
    test "reduces the amount when removing fewer than held" do
      s = storage([item(nameid: @red_potion, amount: 10)])

      assert {:ok, new_s, {:reduced, 0, 7}} = Storage.remove(s, 0, 3)
      assert %{0 => %InventoryItem{amount: 7}} = new_s
    end

    test "removes the slot when the amount hits zero" do
      s = storage([item(nameid: @red_potion, amount: 3)])

      assert {:ok, new_s, {:removed, 0}} = Storage.remove(s, 0, 3)
      assert new_s == %{}
    end

    test "returns :insufficient_amount when removing more than held" do
      s = storage([item(nameid: @red_potion, amount: 2)])

      assert {:error, :insufficient_amount} = Storage.remove(s, 0, 5)
    end
  end

  describe "held_amount/2 and stackable_index/2" do
    test "held_amount sums stackable stacks of the nameid" do
      s = storage([item(nameid: @red_potion, amount: 5), item(nameid: @red_potion, amount: 7)])

      assert Storage.held_amount(s, @red_potion) == 12
    end

    test "stackable_index returns the index of a stackable slot, nil when none" do
      s = storage([item(nameid: @red_potion, amount: 5)])

      assert Storage.stackable_index(s, @red_potion) == 0
      assert Storage.stackable_index(s, @sword) == nil
    end
  end

  describe "storable?/1" do
    test "accepts unbound items" do
      assert Storage.storable?(item(bound: 0))
    end

    test "accepts account-bound items" do
      assert Storage.storable?(item(bound: 1))
    end

    test "rejects guild-bound items" do
      refute Storage.storable?(item(bound: 2))
    end

    test "rejects party-bound items" do
      refute Storage.storable?(item(bound: 3))
    end

    test "rejects character-bound items" do
      refute Storage.storable?(item(bound: 4))
    end
  end
end
