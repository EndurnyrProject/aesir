defmodule Aesir.ZoneServer.Unit.ItemContainerTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.ItemContainer`.

  No DB, no sockets: container maps are built with real `%InventoryItem{}`
  structs and item definitions come from `priv/db/items/` resolved through
  `ItemManagement.get_item_by_id/1`.
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.ItemContainer

  @red_potion 501
  @sword 1101

  @inventory_capacity 100
  @storage_capacity 600

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

  defp container(items) do
    items
    |> Enum.with_index()
    |> Map.new(fn {item, index} -> {index, item} end)
  end

  defp def!(id) do
    {:ok, d} = ItemManagement.get_item_by_id(id)
    d
  end

  describe "add/5" do
    test "adds a new item to an empty container at the lowest free index" do
      def_ = def!(@sword)

      assert {:ok, c, {:added, 0, %InventoryItem{nameid: @sword, amount: 1}}} =
               ItemContainer.add(%{}, def_, 1, @inventory_capacity)

      assert %{0 => %InventoryItem{nameid: @sword}} = c
    end

    test "stacks onto an existing stackable slot of the same nameid" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])

      assert {:ok, new_c, {:stacked, 0, 8}} =
               ItemContainer.add(c, def_, 3, @inventory_capacity)

      assert %{0 => %InventoryItem{amount: 8}} = new_c
    end

    test "does not stack a bound grant onto an unbound stack" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])

      assert {:ok, new_c, {:added, 1, %InventoryItem{amount: 3, bound: 1}}} =
               ItemContainer.add(c, def_, 3, @inventory_capacity, %{bound: 1})

      assert %{
               0 => %InventoryItem{amount: 5, bound: 0},
               1 => %InventoryItem{amount: 3, bound: 1}
             } = new_c
    end

    test "stacks grants with the same bound value" do
      def_ = def!(@red_potion)

      assert {:ok, c, {:added, 0, %InventoryItem{amount: 3, bound: 1}}} =
               ItemContainer.add(%{}, def_, 3, @inventory_capacity, %{bound: 1})

      assert {:ok, new_c, {:stacked, 0, 5}} =
               ItemContainer.add(c, def_, 2, @inventory_capacity, %{bound: 1})

      assert %{0 => %InventoryItem{amount: 5, bound: 1}} = new_c
    end

    test "does not stack onto an equipped item; creates a new slot" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5, equip: 2)])

      assert {:ok, new_c, {:added, 1, %InventoryItem{nameid: @red_potion, amount: 3}}} =
               ItemContainer.add(c, def_, 3, @inventory_capacity)

      assert map_size(new_c) == 2
    end

    test "does not stack onto an item carrying cards" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5, card0: 4001)])

      assert {:ok, _c, {:added, 1, _item}} = ItemContainer.add(c, def_, 3, @inventory_capacity)
    end

    test "30k split-and-spill: tops the existing stack and spills the remainder into a new slot" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 29_999)])

      assert {:ok, new_c, {:split, splits}} = ItemContainer.add(c, def_, 5, @inventory_capacity)
      assert splits == [{0, 30_000}, {1, 4}]
      assert %{0 => %InventoryItem{amount: 30_000}, 1 => %InventoryItem{amount: 4}} = new_c
    end

    test "all-or-nothing: aborts the whole add when full, leaving the container untouched" do
      def_ = def!(@sword)
      full = container(for n <- 1..100, do: item(nameid: 600 + n, amount: 1))

      assert {:error, :inventory_full} = ItemContainer.add(full, def_, 1, @inventory_capacity)
      assert map_size(full) == 100
    end

    test "all-or-nothing: aborts the whole add when the split remainder has no free slot" do
      def_ = def!(@red_potion)

      items =
        [item(nameid: @red_potion, amount: 29_999)] ++
          for(n <- 1..99, do: item(nameid: 700 + n, amount: 1))

      c = container(items)
      assert map_size(c) == 100

      assert {:error, :inventory_full} = ItemContainer.add(c, def_, 5, @inventory_capacity)
      assert %{0 => %InventoryItem{amount: 29_999}} = c
    end

    test "capacity boundary at 100: the 100th slot succeeds, the 101st is rejected" do
      almost_full = container(for n <- 1..99, do: item(nameid: 10_000 + n, amount: 1))

      assert {:ok, full, {:added, 99, _item}} =
               ItemContainer.add(almost_full, def!(@sword), 1, @inventory_capacity)

      assert map_size(full) == 100

      assert {:error, :inventory_full} =
               ItemContainer.add(full, def!(@red_potion), 1, @inventory_capacity)
    end

    test "capacity boundary at 600: the 600th slot succeeds, the 601st is rejected" do
      almost_full = container(for n <- 1..599, do: item(nameid: 10_000 + n, amount: 1))

      assert {:ok, full, {:added, 599, _item}} =
               ItemContainer.add(almost_full, def!(@sword), 1, @storage_capacity)

      assert map_size(full) == 600

      assert {:error, :inventory_full} =
               ItemContainer.add(full, def!(@red_potion), 1, @storage_capacity)
    end
  end

  describe "remove/3" do
    test "reduces the amount when removing fewer than held" do
      c = container([item(nameid: @red_potion, amount: 10)])

      assert {:ok, new_c, {:reduced, 0, 7}} = ItemContainer.remove(c, 0, 3)
      assert %{0 => %InventoryItem{amount: 7}} = new_c
    end

    test "removes the slot when the amount hits zero" do
      c = container([item(nameid: @red_potion, amount: 3)])

      assert {:ok, new_c, {:removed, 0}} = ItemContainer.remove(c, 0, 3)
      assert new_c == %{}
    end

    test "returns :not_found for a missing index" do
      assert {:error, :not_found} = ItemContainer.remove(%{}, 7, 1)
    end

    test "returns :insufficient_amount when removing more than held" do
      c = container([item(nameid: @red_potion, amount: 2)])

      assert {:error, :insufficient_amount} = ItemContainer.remove(c, 0, 5)
    end
  end

  describe "held_amount/2 and stackable_index/2" do
    test "held_amount sums stackable stacks of the nameid" do
      c = container([item(nameid: @red_potion, amount: 5), item(nameid: @red_potion, amount: 7)])

      assert ItemContainer.held_amount(c, @red_potion) == 12
    end

    test "held_amount counts bound and unbound stacks of the nameid" do
      c =
        container([
          item(nameid: @red_potion, amount: 5),
          item(nameid: @red_potion, amount: 7, bound: 1)
        ])

      assert ItemContainer.held_amount(c, @red_potion) == 12
    end

    test "held_amount ignores equipped or carded copies" do
      c =
        container([
          item(nameid: @red_potion, amount: 5, equip: 2),
          item(nameid: @red_potion, amount: 7, card0: 4001)
        ])

      assert ItemContainer.held_amount(c, @red_potion) == 0
    end

    test "stackable_index returns the index of a stackable slot, nil when none" do
      c = container([item(nameid: @red_potion, amount: 5)])

      assert ItemContainer.stackable_index(c, @red_potion) == 0
      assert ItemContainer.stackable_index(c, @sword) == nil
    end
  end

  describe "add_preserving/5" do
    test "a plain item stacks onto an existing plain stack" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 3)

      assert {:ok, new_c, {:stacked, 0, 8}} =
               ItemContainer.add_preserving(c, def_, 3, @inventory_capacity, source)

      assert %{0 => %InventoryItem{amount: 8}} = new_c
    end

    test "a carded item never merges onto a plain stack of the same nameid" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 1, card0: 4001)

      assert {:ok, new_c, {:added, 1, %InventoryItem{card0: 4001}}} =
               ItemContainer.add_preserving(c, def_, 1, @inventory_capacity, source)

      assert %{0 => %InventoryItem{amount: 5, card0: 0}, 1 => %InventoryItem{card0: 4001}} =
               new_c
    end

    test "a refined item never merges onto a plain stack" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 1, refine: 7)

      assert {:ok, new_c, {:added, 1, %InventoryItem{refine: 7}}} =
               ItemContainer.add_preserving(c, def_, 1, @inventory_capacity, source)

      assert map_size(new_c) == 2
    end

    test "an item carrying random options never merges onto a plain stack" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 1, random_options: %{"1" => %{val: 5, parm: 0}})

      assert {:ok, new_c, {:added, 1, _item}} =
               ItemContainer.add_preserving(c, def_, 1, @inventory_capacity, source)

      assert map_size(new_c) == 2
    end

    test "unique_id, enchant_grade, and expire_time survive the transfer round-trip" do
      def_ = def!(@red_potion)
      expire_time = ~N[2030-01-01 00:00:00]

      source =
        item(nameid: @red_potion, amount: 1, unique_id: 123, enchant_grade: 2)
        |> Map.put(:expire_time, expire_time)

      assert {:ok, new_c, {:added, 0, _item}} =
               ItemContainer.add_preserving(%{}, def_, 1, @inventory_capacity, source)

      assert %{
               0 => %InventoryItem{
                 unique_id: 123,
                 enchant_grade: 2,
                 expire_time: ^expire_time
               }
             } = new_c
    end

    test "respects the destination's capacity parameter" do
      def_ = def!(@red_potion)
      full = container(for n <- 1..100, do: item(nameid: 600 + n, amount: 1, card0: 4001))
      source = item(nameid: @red_potion, amount: 1, card0: 4001)

      assert {:error, :inventory_full} =
               ItemContainer.add_preserving(full, def_, 1, @inventory_capacity, source)
    end
  end

  describe "plain?/1" do
    test "a default item is plain" do
      assert ItemContainer.plain?(item(nameid: @red_potion))
    end

    test "cards, refine, random options, bound, favorite, unique_id, enchant_grade, and expire_time all make an item not plain" do
      refute ItemContainer.plain?(item(nameid: @red_potion, card0: 4001))
      refute ItemContainer.plain?(item(nameid: @red_potion, refine: 1))
      refute ItemContainer.plain?(item(nameid: @red_potion, random_options: %{"1" => %{}}))
      refute ItemContainer.plain?(item(nameid: @red_potion, bound: 1))
      refute ItemContainer.plain?(item(nameid: @red_potion, favorite: 1))
      refute ItemContainer.plain?(item(nameid: @red_potion, unique_id: 1))
      refute ItemContainer.plain?(item(nameid: @red_potion, enchant_grade: 1))

      refute ItemContainer.plain?(
               item(nameid: @red_potion)
               |> Map.put(:expire_time, ~N[2030-01-01 00:00:00])
             )
    end
  end

  describe "index-map helpers" do
    test "put_item/3 puts an item at the given index" do
      c = ItemContainer.put_item(%{}, 0, item(nameid: @red_potion))

      assert %{0 => %InventoryItem{nameid: @red_potion}} = c
    end

    test "get_by_index/2 returns the item or nil" do
      c = container([item(nameid: @red_potion)])

      assert %InventoryItem{nameid: @red_potion} = ItemContainer.get_by_index(c, 0)
      assert ItemContainer.get_by_index(c, 1) == nil
    end

    test "delete_index/2 removes the item at the given index" do
      c = container([item(nameid: @red_potion)])

      assert ItemContainer.delete_index(c, 0) == %{}
    end

    test "lowest_free_index/1 returns the smallest unused index" do
      c = container([item(nameid: @red_potion), item(nameid: @sword)])

      assert ItemContainer.lowest_free_index(c) == 2
      assert ItemContainer.lowest_free_index(%{}) == 0
    end
  end
end
