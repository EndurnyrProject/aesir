defmodule Aesir.ZoneServer.Unit.InventoryTest do
  @moduledoc """
  Pure-domain tests for `Aesir.ZoneServer.Unit.Inventory`.

  No DB, no sockets: inventory maps are built with real `%InventoryItem{}`
  structs via `PlayerState.from_list/1` and equip uses real item ids from
  `priv/db/items/equip.yml` resolved through `ItemManagement.get_item_by_id/1`.
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Real equip.yml ids used across the suite.
  @sword 1101
  @katana 1116
  @shield 2101
  @body_armor 2301
  @ring 2601
  @earring 2602
  @amistr_cap 5766

  # EQP position bitmasks (rAthena enum equip_pos).
  @right_hand 2
  @left_hand 32
  @armor_pos 16
  @right_accessory 8
  @left_accessory 128
  @both_hand 34
  @both_accessory 136
  @head_top 256

  # Job ids: swordman (1) can wear the katana, novice (0) cannot.
  @swordman 1
  @novice 0

  defp item(attrs) do
    base = %{
      id: System.unique_integer([:positive]),
      char_id: 1,
      nameid: 501,
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

  defp inventory(items), do: PlayerState.from_list(items)

  defp def!(id) do
    {:ok, d} = ItemManagement.get_item_by_id(id)
    d
  end

  describe "add/4" do
    test "adds a new item to an empty inventory at the lowest free index" do
      def_ = def!(@sword)

      assert {:ok, inv, {:added, 0, %InventoryItem{nameid: @sword, amount: 1}}} =
               Inventory.add(%{}, def_, 1)

      assert %{0 => %InventoryItem{nameid: @sword}} = inv
    end

    test "stacks into an existing stackable item of the same nameid" do
      def_ = def!(501)
      inv = inventory([item(nameid: 501, amount: 5)])

      assert {:ok, new_inv, {:stacked, 0, 8}} = Inventory.add(inv, def_, 3)
      assert %{0 => %InventoryItem{amount: 8}} = new_inv
    end

    test "does not stack onto an equipped item; creates a new slot" do
      def_ = def!(501)
      inv = inventory([item(nameid: 501, amount: 5, equip: 2)])

      assert {:ok, new_inv, {:added, 1, %InventoryItem{nameid: 501, amount: 3}}} =
               Inventory.add(inv, def_, 3)

      assert map_size(new_inv) == 2
    end

    test "does not stack onto an item carrying cards" do
      def_ = def!(501)
      inv = inventory([item(nameid: 501, amount: 5, card0: 4001)])

      assert {:ok, _inv, {:added, 1, _item}} = Inventory.add(inv, def_, 3)
    end

    test "overflow past max stack tops the existing stack and splits remainder into a new slot" do
      def_ = def!(501)
      inv = inventory([item(nameid: 501, amount: 29_999)])

      assert {:ok, new_inv, {:split, splits}} = Inventory.add(inv, def_, 5)
      assert splits == [{0, 30_000}, {1, 4}]
      assert %{0 => %InventoryItem{amount: 30_000}, 1 => %InventoryItem{amount: 4}} = new_inv
    end

    test "rejects with :inventory_full when there is no free index, leaving the map unchanged" do
      def_ = def!(@sword)
      full = inventory(for n <- 1..100, do: item(nameid: 600 + n, amount: 1))

      assert {:error, :inventory_full} = Inventory.add(full, def_, 1)
    end

    test "rejects the whole add when the split remainder has no free slot" do
      def_ = def!(501)

      items =
        [item(nameid: 501, amount: 29_999)] ++
          for(n <- 1..99, do: item(nameid: 700 + n, amount: 1))

      inv = inventory(items)
      assert map_size(inv) == 100

      assert {:error, :inventory_full} = Inventory.add(inv, def_, 5)
    end
  end

  describe "remove/3" do
    test "reduces the amount when removing fewer than held" do
      inv = inventory([item(nameid: 501, amount: 10)])

      assert {:ok, new_inv, {:reduced, 0, 7}} = Inventory.remove(inv, 0, 3)
      assert %{0 => %InventoryItem{amount: 7}} = new_inv
    end

    test "removes the slot when the amount hits zero" do
      inv = inventory([item(nameid: 501, amount: 3)])

      assert {:ok, new_inv, {:removed, 0}} = Inventory.remove(inv, 0, 3)
      assert new_inv == %{}
    end

    test "returns :not_found for a missing index" do
      assert {:error, :not_found} = Inventory.remove(%{}, 7, 1)
    end

    test "returns :insufficient_amount when removing more than held" do
      inv = inventory([item(nameid: 501, amount: 2)])

      assert {:error, :insufficient_amount} = Inventory.remove(inv, 0, 5)
    end
  end

  describe "equip/4" do
    setup do
      %{ctx: %{job_id: @swordman, base_level: 99}}
    end

    test "equips a one-handed weapon to its right-hand location", %{ctx: ctx} do
      inv = inventory([item(nameid: @sword, amount: 1)])

      assert {:ok, new_inv, {:equipped, 0, location, []}} =
               Inventory.equip(inv, 0, @right_hand, ctx)

      assert location == 2
      assert %{0 => %InventoryItem{equip: 2}} = new_inv
    end

    test "auto-unequips the occupant of a location being taken", %{ctx: ctx} do
      inv =
        inventory([
          item(nameid: @sword, amount: 1, equip: 2),
          item(nameid: @sword, amount: 1)
        ])

      assert {:ok, new_inv, {:equipped, 1, 2, [0]}} = Inventory.equip(inv, 1, @right_hand, ctx)
      assert %{0 => %InventoryItem{equip: 0}, 1 => %InventoryItem{equip: 2}} = new_inv
    end

    test "a two-handed weapon clears both hands", %{ctx: ctx} do
      inv =
        inventory([
          item(nameid: @sword, amount: 1, equip: 2),
          item(nameid: @shield, amount: 1, equip: 32),
          item(nameid: @katana, amount: 1)
        ])

      assert {:ok, new_inv, {:equipped, 2, location, unequipped}} =
               Inventory.equip(inv, 2, @both_hand, ctx)

      assert location == 34
      assert Enum.sort(unequipped) == [0, 1]
      assert %{0 => %InventoryItem{equip: 0}, 1 => %InventoryItem{equip: 0}} = new_inv
      assert %{2 => %InventoryItem{equip: 34}} = new_inv
    end

    test "equipping a shield while a two-hander is worn unequips the two-hander", %{ctx: ctx} do
      inv =
        inventory([
          item(nameid: @katana, amount: 1, equip: 34),
          item(nameid: @shield, amount: 1)
        ])

      assert {:ok, new_inv, {:equipped, 1, 32, [0]}} = Inventory.equip(inv, 1, @left_hand, ctx)
      assert %{0 => %InventoryItem{equip: 0}, 1 => %InventoryItem{equip: 32}} = new_inv
    end

    test "two distinct accessories occupy the right then left slot simultaneously", %{ctx: ctx} do
      inv = inventory([item(nameid: @ring, amount: 1), item(nameid: @earring, amount: 1)])

      assert {:ok, inv, {:equipped, 0, @right_accessory, []}} =
               Inventory.equip(inv, 0, @right_accessory, ctx)

      assert {:ok, inv, {:equipped, 1, @left_accessory, []}} =
               Inventory.equip(inv, 1, @left_accessory, ctx)

      assert %{
               0 => %InventoryItem{equip: @right_accessory},
               1 => %InventoryItem{equip: @left_accessory}
             } = Inventory.equipped_items(inv)
    end

    test "ambiguous accessory position picks the free slot when one is occupied", %{ctx: ctx} do
      inv =
        inventory([
          item(nameid: @ring, amount: 1, equip: @right_accessory),
          item(nameid: @earring, amount: 1)
        ])

      assert {:ok, new_inv, {:equipped, 1, @left_accessory, []}} =
               Inventory.equip(inv, 1, @both_accessory, ctx)

      assert %{
               0 => %InventoryItem{equip: @right_accessory},
               1 => %InventoryItem{equip: @left_accessory}
             } = new_inv
    end

    test "ambiguous accessory position evicts the right slot when both are occupied", %{ctx: ctx} do
      inv =
        inventory([
          item(nameid: @ring, amount: 1, equip: @right_accessory),
          item(nameid: @ring, amount: 1, equip: @left_accessory),
          item(nameid: @earring, amount: 1)
        ])

      assert {:ok, new_inv, {:equipped, 2, @right_accessory, [0]}} =
               Inventory.equip(inv, 2, @both_accessory, ctx)

      assert %{
               0 => %InventoryItem{equip: 0},
               1 => %InventoryItem{equip: @left_accessory},
               2 => %InventoryItem{equip: @right_accessory}
             } = new_inv
    end

    test "wears the item at its own location, ignoring a mismatched requested position", %{
      ctx: ctx
    } do
      inv = inventory([item(nameid: @sword, amount: 1)])

      assert {:ok, %{0 => %InventoryItem{equip: @right_hand}}, {:equipped, 0, @right_hand, []}} =
               Inventory.equip(inv, 0, @armor_pos, ctx)
    end

    test "wears the item at its own location when the requested position is zero", %{ctx: ctx} do
      inv = inventory([item(nameid: @sword, amount: 1)])

      assert {:ok, %{0 => %InventoryItem{equip: @right_hand}}, {:equipped, 0, @right_hand, []}} =
               Inventory.equip(inv, 0, 0, ctx)
    end

    test "equips a head_top headgear regardless of the client position", %{ctx: ctx} do
      inv = inventory([item(nameid: @amistr_cap, amount: 1)])

      assert {:ok, %{0 => %InventoryItem{equip: @head_top}}, {:equipped, 0, @head_top, []}} =
               Inventory.equip(inv, 0, 0, ctx)
    end

    test "returns :not_found for a missing index", %{ctx: ctx} do
      assert {:error, :not_found} = Inventory.equip(%{}, 5, @right_hand, ctx)
    end

    test "returns :cannot_equip for a non-equipment item", %{ctx: ctx} do
      inv = inventory([item(nameid: 501, amount: 1)])

      assert {:error, :cannot_equip} = Inventory.equip(inv, 0, @right_hand, ctx)
    end

    test "returns :requirement_unmet when the job cannot wear the item" do
      inv = inventory([item(nameid: @katana, amount: 1)])
      ctx = %{job_id: @novice, base_level: 99}

      assert {:error, :requirement_unmet} = Inventory.equip(inv, 0, @both_hand, ctx)
    end

    test "returns :requirement_unmet when below equip_level_min" do
      inv = inventory([item(nameid: @sword, amount: 1)])
      ctx = %{job_id: @swordman, base_level: 1}

      assert {:error, :requirement_unmet} = Inventory.equip(inv, 0, @right_hand, ctx)
    end

    test "returns :item_broken for a broken item", %{ctx: ctx} do
      inv = inventory([item(nameid: @sword, amount: 1, attribute: 1)])

      assert {:error, :item_broken} = Inventory.equip(inv, 0, @right_hand, ctx)
    end

    test "equips an item with empty jobs list (all jobs allowed)", %{ctx: ctx} do
      inv = inventory([item(nameid: @shield, amount: 1)])

      assert {:ok, _inv, {:equipped, 0, 32, []}} = Inventory.equip(inv, 0, @left_hand, ctx)
    end
  end

  describe "unequip/2" do
    test "unequips an equipped item" do
      inv = inventory([item(nameid: @sword, amount: 1, equip: 2)])

      assert {:ok, new_inv, {:unequipped, 0}} = Inventory.unequip(inv, 0)
      assert %{0 => %InventoryItem{equip: 0}} = new_inv
    end

    test "returns :not_found for a missing index" do
      assert {:error, :not_found} = Inventory.unequip(%{}, 3)
    end

    test "returns :not_equipped when the item is not equipped" do
      inv = inventory([item(nameid: @sword, amount: 1)])

      assert {:error, :not_equipped} = Inventory.unequip(inv, 0)
    end
  end

  describe "equipped_items/1" do
    test "returns only items with a non-zero equip bitmask, keyed by index" do
      inv =
        inventory([
          item(nameid: @sword, amount: 1, equip: 2),
          item(nameid: 501, amount: 5),
          item(nameid: @body_armor, amount: 1, equip: 16)
        ])

      equipped = Inventory.equipped_items(inv)

      assert %{0 => %InventoryItem{equip: 2}, 2 => %InventoryItem{equip: 16}} = equipped
      assert map_size(equipped) == 2
    end
  end
end
