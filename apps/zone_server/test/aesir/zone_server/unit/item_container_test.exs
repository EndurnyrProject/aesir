defmodule Aesir.ZoneServer.Unit.ItemContainerTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.ItemContainer`.

  No DB, no sockets: container maps are built with real `%InventoryItem{}`
  structs and item definitions come from `priv/db/re/items/` resolved through
  `ItemManagement.get_item_by_id/1`.
  """
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.ItemContainer

  @red_potion 501
  @sword 1101

  @card 4001

  @inventory_capacity 100
  @storage_capacity 600
  @inventory_room %{capacity: @inventory_capacity, weight: :infinity}
  @cart_room %{capacity: 100, weight: :infinity}
  @storage_room %{capacity: @storage_capacity, weight: :infinity}

  setup :set_mimic_private

  defp item(attrs \\ []) do
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

  defp put(container, kind, def_, amount, opts \\ %{}, room \\ @inventory_room) do
    ItemContainer.put(container, kind, def_, ItemContainer.new_item(def_, opts), amount, room)
  end

  defp move(container, kind, def_, amount, source, room \\ @inventory_room) do
    ItemContainer.put(container, kind, def_, source, amount, room)
  end

  defp limit(def_, kind, amount), do: %{def_ | stack_limit: %{kind => amount}}

  describe "put/6" do
    test "adds a new item to an empty container at the lowest free index" do
      def_ = def!(@sword)

      assert {:ok, c, {:added, 0, %InventoryItem{nameid: @sword, amount: 1}}} =
               put(%{}, :inventory, def_, 1)

      assert %{0 => %InventoryItem{nameid: @sword}} = c
    end

    test "stacks onto an existing stackable slot of the same nameid" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])

      assert {:ok, new_c, {:stacked, 0, 8}} = put(c, :inventory, def_, 3)

      assert %{0 => %InventoryItem{amount: 8}} = new_c
    end

    test "does not stack a bound grant onto an unbound stack" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])

      assert {:ok, new_c, {:added, 1, %InventoryItem{amount: 3, bound: 1}}} =
               put(c, :inventory, def_, 3, %{bound: 1})

      assert %{
               0 => %InventoryItem{amount: 5, bound: 0},
               1 => %InventoryItem{amount: 3, bound: 1}
             } = new_c
    end

    test "stacks grants with the same bound value" do
      def_ = def!(@red_potion)

      assert {:ok, c, {:added, 0, %InventoryItem{amount: 3, bound: 1}}} =
               put(%{}, :inventory, def_, 3, %{bound: 1})

      assert {:ok, new_c, {:stacked, 0, 5}} = put(c, :inventory, def_, 2, %{bound: 1})

      assert %{0 => %InventoryItem{amount: 5, bound: 1}} = new_c
    end

    test "stores craft metadata on a newly added item" do
      def_ = def!(@red_potion)
      craft = %{"kind" => "signed", "creator_char_id" => 1}

      assert {:ok, _c, {:added, 0, %InventoryItem{craft: ^craft}}} =
               put(%{}, :inventory, def_, 1, %{craft: craft})
    end

    test "craft-bearing and plain items occupy separate slots" do
      def_ = def!(@red_potion)
      craft = %{"kind" => "signed", "creator_char_id" => 1}

      assert {:ok, crafted, {:added, 0, %InventoryItem{craft: ^craft}}} =
               put(%{}, :inventory, def_, 1, %{craft: craft})

      assert {:ok, craft_then_plain, {:added, 1, %InventoryItem{craft: nil}}} =
               put(crafted, :inventory, def_, 1)

      assert {:ok, plain, {:added, 0, %InventoryItem{craft: nil}}} = put(%{}, :inventory, def_, 1)

      assert {:ok, plain_then_craft, {:added, 1, %InventoryItem{craft: ^craft}}} =
               put(plain, :inventory, def_, 1, %{craft: craft})

      assert map_size(craft_then_plain) == 2
      assert map_size(plain_then_craft) == 2
    end

    test "stacks onto an equipped stack" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5, equip: 2)])

      assert {:ok, new_c, {:stacked, 0, 8}} = put(c, :inventory, def_, 3)
      assert %{0 => %InventoryItem{amount: 8, equip: 2}} = new_c
    end

    test "does not stack onto an item carrying cards" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5, card0: 4001)])

      assert {:ok, _c, {:added, 1, _item}} = put(c, :inventory, def_, 3)
    end

    test "refuses with :over_amount when the stack would pass 30,000, leaving the container untouched" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 29_999)])

      assert {:ok, _c, {:stacked, 0, 30_000}} = put(c, :inventory, def_, 1)
      assert {:error, :over_amount} = put(c, :inventory, def_, 5)
      assert %{0 => %InventoryItem{amount: 29_999}} = c
    end

    test "all-or-nothing: aborts the whole add when full, leaving the container untouched" do
      def_ = def!(@sword)
      full = container(for n <- 1..100, do: item(nameid: 600 + n, amount: 1))

      assert {:error, :inventory_full} = put(full, :inventory, def_, 1)
      assert map_size(full) == 100
    end

    test "a full stack refuses with :over_amount even when no slot is free" do
      def_ = def!(@red_potion)

      items =
        [item(nameid: @red_potion, amount: 29_999)] ++
          for(n <- 1..99, do: item(nameid: 700 + n, amount: 1))

      c = container(items)
      assert map_size(c) == 100

      assert {:error, :over_amount} = put(c, :inventory, def_, 5)
      assert %{0 => %InventoryItem{amount: 29_999}} = c
    end

    test "capacity boundary at 100: the 100th slot succeeds, the 101st is rejected" do
      almost_full = container(for n <- 1..99, do: item(nameid: 10_000 + n, amount: 1))

      assert {:ok, full, {:added, 99, _item}} = put(almost_full, :inventory, def!(@sword), 1)

      assert map_size(full) == 100

      assert {:error, :inventory_full} = put(full, :inventory, def!(@red_potion), 1)
    end

    test "capacity boundary at 600: the 600th slot succeeds, the 601st is rejected" do
      almost_full = container(for n <- 1..599, do: item(nameid: 10_000 + n, amount: 1))

      assert {:ok, full, {:added, 599, _item}} =
               put(almost_full, :storage, def!(@sword), 1, %{}, @storage_room)

      assert map_size(full) == 600

      assert {:error, :storage_full} =
               put(full, :storage, def!(@red_potion), 1, %{}, @storage_room)
    end

    test "a moved plain item stacks onto an existing plain stack" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 3)

      assert {:ok, new_c, {:stacked, 0, 8}} = move(c, :inventory, def_, 3, source)
      assert %{0 => %InventoryItem{amount: 8}} = new_c
    end

    test "a carded item never merges onto a plain stack of the same nameid" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 1, card0: 4001)

      assert {:ok, new_c, {:added, 1, %InventoryItem{card0: 4001}}} =
               move(c, :inventory, def_, 1, source)

      assert %{0 => %InventoryItem{amount: 5, card0: 0}, 1 => %InventoryItem{card0: 4001}} =
               new_c
    end

    test "a refined item merges in the inventory but not in storage" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 1, refine: 7)

      assert {:ok, _c, {:stacked, 0, 6}} = move(c, :inventory, def_, 1, source)

      assert {:ok, stored, {:added, 1, %InventoryItem{refine: 7}}} =
               move(c, :storage, def_, 1, source, @storage_room)

      assert map_size(stored) == 2
    end

    test "random options are not part of a stack's identity" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])
      source = item(nameid: @red_potion, amount: 1, random_options: %{"1" => %{val: 5, parm: 0}})

      assert {:ok, _c, {:stacked, 0, 6}} = move(c, :inventory, def_, 1, source)
      assert {:ok, _c, {:stacked, 0, 6}} = move(c, :storage, def_, 1, source, @storage_room)
    end

    test "unique_id, enchant_grade, and expire_time survive the transfer round-trip" do
      def_ = def!(@red_potion)
      expire_time = ~N[2030-01-01 00:00:00]

      source =
        item(nameid: @red_potion, amount: 1, unique_id: 123, enchant_grade: 2)
        |> Map.put(:expire_time, expire_time)

      assert {:ok, new_c, {:added, 0, _item}} = move(%{}, :inventory, def_, 1, source)

      assert %{
               0 => %InventoryItem{
                 unique_id: 123,
                 enchant_grade: 2,
                 expire_time: ^expire_time
               }
             } = new_c
    end

    test "craft metadata survives the transfer round-trip" do
      def_ = def!(@red_potion)
      craft = %{"kind" => "signed", "creator_char_id" => 1}
      source = item(nameid: @red_potion, amount: 1, craft: craft)

      assert {:ok, new_c, {:added, 0, %InventoryItem{craft: ^craft}}} =
               move(%{}, :inventory, def_, 1, source)

      assert %{0 => %InventoryItem{craft: ^craft}} = new_c
    end

    test "respects the destination's capacity" do
      def_ = def!(@red_potion)
      full = container(for n <- 1..100, do: item(nameid: 600 + n, amount: 1, card0: 4001))
      source = item(nameid: @red_potion, amount: 1, card0: 4001)

      assert {:error, :inventory_full} = move(full, :inventory, def_, 1, source)
    end
  end

  describe "put/6 inventory recipe" do
    test "refuses in the reference order: amount, 30,000, stack limit, weight" do
      limited = limit(def!(@red_potion), :inventory, 3)
      tight = %{@inventory_room | weight: 0}

      assert {:error, :invalid} = put(%{}, :inventory, limited, 0, %{}, tight)
      assert {:error, :over_amount} = put(%{}, :inventory, limited, 30_001, %{}, tight)
      assert {:error, :stack_limit} = put(%{}, :inventory, limited, 4, %{}, tight)
      assert {:error, :overweight} = put(%{}, :inventory, limited, 3, %{}, tight)
      assert {:ok, _c, {:added, 0, _item}} = put(%{}, :inventory, limited, 3)
    end

    test "a stack that would pass the stack limit refuses with :over_amount" do
      limited = limit(def!(@red_potion), :inventory, 3)
      c = container([item(nameid: @red_potion, amount: 2)])

      assert {:ok, _c, {:stacked, 0, 3}} = put(c, :inventory, limited, 1)
      assert {:error, :over_amount} = put(c, :inventory, limited, 2)
    end

    test "a stack limit for another container does not apply" do
      limited = limit(def!(@red_potion), :cart, 1)

      assert {:ok, _c, {:added, 0, %InventoryItem{amount: 5}}} = put(%{}, :inventory, limited, 5)
    end

    test "weight passes at exactly the free weight" do
      def_ = def!(@red_potion)
      room = %{@inventory_room | weight: def_.weight * 2}

      assert {:ok, _c, _change} = put(%{}, :inventory, def_, 2, %{}, room)
      assert {:error, :overweight} = put(%{}, :inventory, def_, 3, %{}, room)
    end

    test "a non-stackable item never merges and takes one slot for every amount" do
      def_ = def!(@sword)
      c = container([item(nameid: @sword, amount: 1)])

      assert {:ok, new_c, {:added, 1, %InventoryItem{amount: 2}}} = put(c, :inventory, def_, 2)
      assert map_size(new_c) == 2
    end

    test "an expiring item never merges, nor merges into an expiring stack" do
      def_ = def!(@red_potion)
      expire_time = ~N[2030-01-01 00:00:00]
      rental_stack = container([item(nameid: @red_potion, amount: 5, expire_time: expire_time)])

      assert {:ok, _c, {:added, 1, _item}} = put(rental_stack, :inventory, def_, 1)

      assert {:ok, _c, {:added, 1, %InventoryItem{expire_time: ^expire_time}}} =
               put(rental_stack, :inventory, def_, 1, %{expire_time: expire_time})
    end

    test "merges into the lowest matching index" do
      def_ = def!(@red_potion)
      c = for index <- [40, 3, 17], into: %{}, do: {index, item(nameid: @red_potion, amount: 1)}

      assert {:ok, _c, {:stacked, 3, 2}} = put(c, :inventory, def_, 1)
    end

    test "a new slot is neither worn nor a favourite" do
      def_ = def!(@red_potion)
      source = item(nameid: @red_potion, amount: 1, equip: 2, favorite: 1)

      assert {:ok, _c, {:added, 0, %InventoryItem{equip: 0, favorite: 0}}} =
               move(%{}, :inventory, def_, 1, source)
    end
  end

  describe "put/6 cart recipe" do
    test "refuses in the reference order: amount, stack limit, restriction, weight, room" do
      def_ = limit(def!(@red_potion), :cart, 3)
      restricted = %{def_ | no_cart: true}
      tight = %{@cart_room | weight: 0}

      assert {:error, :invalid} = put(%{}, :cart, restricted, 0, %{}, tight)
      assert {:error, :stack_limit} = put(%{}, :cart, restricted, 4, %{}, tight)
      assert {:error, :restricted} = put(%{}, :cart, restricted, 1, %{}, tight)
      assert {:error, :overweight} = put(%{}, :cart, def_, 1, %{}, tight)

      full = container(for n <- 1..100, do: item(nameid: 10_000 + n, amount: 1))
      assert {:error, :over_amount} = put(full, :cart, def_, 1, %{}, @cart_room)
    end

    test "a binding past the account is restricted" do
      def_ = def!(@red_potion)

      assert {:ok, _c, _change} = put(%{}, :cart, def_, 1, %{bound: 1}, @cart_room)

      for bound <- [2, 3, 4] do
        assert {:error, :restricted} = put(%{}, :cart, def_, 1, %{bound: bound}, @cart_room)
      end
    end

    test "merges into a held stack whatever its expiry, and clears the favourite" do
      def_ = def!(@red_potion)
      held = item(nameid: @red_potion, amount: 5, expire_time: ~N[2030-01-01 00:00:00])

      assert {:ok, _c, {:stacked, 0, 6}} = put(container([held]), :cart, def_, 1, %{}, @cart_room)

      assert {:ok, _c, {:added, 0, %InventoryItem{favorite: 0}}} =
               move(%{}, :cart, def_, 1, item(nameid: @red_potion, favorite: 1), @cart_room)
    end
  end

  describe "put/6 storage recipes" do
    test "storage refuses the restriction as :restricted and a binding past the account as :bound" do
      def_ = def!(@red_potion)

      assert {:error, :restricted} =
               put(%{}, :storage, %{def_ | no_storage: true}, 1, %{}, @storage_room)

      assert {:ok, _c, _change} = put(%{}, :storage, def_, 1, %{bound: 1}, @storage_room)

      for bound <- [2, 3, 4] do
        assert {:error, :bound} = put(%{}, :storage, def_, 1, %{bound: bound}, @storage_room)
      end
    end

    test "storage keeps the rental expiry and the favourite, and merges only on equal expiry" do
      def_ = def!(@red_potion)
      expire_time = ~N[2030-01-01 00:00:00]
      source = item(nameid: @red_potion, amount: 1, favorite: 1, expire_time: expire_time)

      assert {:ok, stored, {:added, 0, %InventoryItem{favorite: 1, expire_time: ^expire_time}}} =
               move(%{}, :storage, def_, 1, source, @storage_room)

      assert {:ok, _c, {:stacked, 0, 2}} = move(stored, :storage, def_, 1, source, @storage_room)
      assert {:ok, _c, {:added, 1, _item}} = put(stored, :storage, def_, 1, %{}, @storage_room)
    end

    test "storage merges only on equal identify and attribute" do
      def_ = def!(@red_potion)
      c = container([item(nameid: @red_potion, amount: 5)])

      assert {:ok, _c, {:added, 1, _item}} =
               put(c, :storage, def_, 1, %{identify: 0}, @storage_room)

      assert {:ok, _c, {:added, 1, _item}} =
               put(c, :storage, def_, 1, %{attribute: 1}, @storage_room)
    end

    test "the storage stack limit and a full stack refuse as :storage_full" do
      def_ = limit(def!(@red_potion), :storage, 3)
      c = container([item(nameid: @red_potion, amount: 2)])

      assert {:error, :storage_full} = put(%{}, :storage, def_, 4, %{}, @storage_room)
      assert {:error, :storage_full} = put(c, :storage, def_, 2, %{}, @storage_room)

      assert {:error, :storage_full} =
               put(
                 container([item(nameid: @red_potion, amount: 29_999)]),
                 :storage,
                 def!(@red_potion),
                 2,
                 %{},
                 @storage_room
               )
    end

    test "guild storage refuses an expiring item and any binding but the guild's" do
      def_ = def!(@red_potion)
      room = %{capacity: 200, weight: :infinity}

      assert {:error, :restricted} =
               put(%{}, :guild_storage, def_, 1, %{expire_time: ~N[2030-01-01 00:00:00]}, room)

      assert {:ok, _c, _change} = put(%{}, :guild_storage, def_, 1, %{bound: 2}, room)

      for bound <- [1, 3, 4] do
        assert {:error, :bound} = put(%{}, :guild_storage, def_, 1, %{bound: bound}, room)
      end
    end
  end

  describe "restricted?/3" do
    test "reads the item's own flag" do
      assert ItemContainer.restricted?(item(), %{def!(@red_potion) | no_cart: true}, :no_cart)
      refute ItemContainer.restricted?(item(), def!(@red_potion), :no_cart)
    end

    test "reads restricted cards only within the item's slots and never on a crafted item" do
      card = def!(@card)

      stub(ItemManagement, :get_item_by_id, fn
        @card -> {:ok, %{card | no_storage: true}}
        item_id -> Mimic.call_original(ItemManagement, :get_item_by_id, [item_id])
      end)

      two_slots = %{def!(@sword) | slots: 2}

      assert ItemContainer.restricted?(item(card1: @card), two_slots, :no_storage)
      refute ItemContainer.restricted?(item(card2: @card), two_slots, :no_storage)
      refute ItemContainer.restricted?(item(card0: @card), %{two_slots | slots: 0}, :no_storage)

      refute ItemContainer.restricted?(
               item(card1: @card, craft: %{"kind" => "signed", "creator_char_id" => 1}),
               two_slots,
               :no_storage
             )
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
