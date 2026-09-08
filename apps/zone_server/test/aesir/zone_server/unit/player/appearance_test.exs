defmodule Aesir.ZoneServer.Unit.Player.AppearanceTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.LookType
  alias Aesir.ZoneServer.Unit.Player.Appearance
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :set_mimic_private
  setup :setup_ets_tables
  setup :verify_on_exit!

  @gid 1001

  # Real equip.yml ids with known view values.
  @sword 1101
  @guard 2101
  @wedding_veil 2206
  @sunglasses 2201
  @flu_mask 2218
  @muffler 2501
  @muramasa 1173

  # Known views: wedding_veil => 44, sunglasses => 12, flu_mask => 8,
  # guard => 1, Muramasa's two-handed-sword class => 3, sword => 0.

  # EQP position bitmasks.
  @right_hand 2
  @left_hand 32
  @both_hand 34
  @head_top_pos 256
  @head_mid_pos 512
  @head_low_pos 1
  @garment_pos 4

  defp equipped(nameid, equip) do
    %InventoryItem{nameid: nameid, amount: 1, equip: equip, identify: 1}
  end

  describe "look_views/1" do
    test "weapon slot carries weapon_view in val and shield_view in val2" do
      equipment =
        Stats.equipment_from_inventory([
          equipped(@sword, @right_hand),
          equipped(@guard, @left_hand)
        ])

      views = Appearance.look_views(equipment)

      assert views.weapon == {2, 1}
      assert views.head_top == {0, 0}
      assert views.robe == {0, 0}
    end
  end

  describe "diff/3" do
    test "emits a single head_top SpriteChange when only the head-top view changes" do
      old = %Equipment{}
      new = Stats.equipment_from_inventory([equipped(@wedding_veil, @head_top_pos)])

      assert [%SpriteChange{gid: @gid, type: type, val: 44, val2: 0}] =
               Appearance.diff(@gid, old, new)

      assert type == LookType.head_top()
    end

    test "returns an empty list when nothing changes" do
      equipment = Stats.equipment_from_inventory([equipped(@wedding_veil, @head_top_pos)])

      assert Appearance.diff(@gid, equipment, equipment) == []
    end

    test "emits val 0 when a slot is cleared by unequip" do
      old = Stats.equipment_from_inventory([equipped(@wedding_veil, @head_top_pos)])
      new = %Equipment{}

      assert [%SpriteChange{gid: @gid, type: type, val: 0, val2: 0}] =
               Appearance.diff(@gid, old, new)

      assert type == LookType.head_top()
    end

    test "weapon and shield changes collapse into a single weapon SpriteChange" do
      old = %Equipment{}

      new =
        Stats.equipment_from_inventory([
          equipped(@sword, @right_hand),
          equipped(@guard, @left_hand)
        ])

      assert [%SpriteChange{gid: @gid, type: type, val: 2, val2: 1}] =
               Appearance.diff(@gid, old, new)

      assert type == LookType.weapon()
    end

    test "a two-handed weapon emits one weapon SpriteChange with shield val 0" do
      old = %Equipment{}
      new = Stats.equipment_from_inventory([equipped(@muramasa, @both_hand)])

      assert [%SpriteChange{gid: @gid, type: type, val: 3, val2: 0}] =
               Appearance.diff(@gid, old, new)

      assert type == LookType.weapon()
    end
  end

  describe "spawn_fields/1" do
    test "maps each equipment slot to the matching spawn field" do
      {:ok, muffler} = ItemManagement.get_item_by_id(@muffler)

      stub(ItemManagement, :get_item_by_id, fn
        @muffler -> {:ok, %{muffler | view: 2}}
        item_id -> Mimic.call_original(ItemManagement, :get_item_by_id, [item_id])
      end)

      equipment =
        Stats.equipment_from_inventory([
          equipped(@wedding_veil, @head_top_pos),
          equipped(@sunglasses, @head_mid_pos),
          equipped(@flu_mask, @head_low_pos),
          equipped(@muffler, @garment_pos),
          equipped(@guard, @left_hand)
        ])

      assert Appearance.spawn_fields(equipment) == %{
               weapon: 0,
               shield: 1,
               accessory: 8,
               accessory2: 12,
               accessory3: 44,
               robe: 2
             }
    end
  end
end
