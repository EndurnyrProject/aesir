defmodule Aesir.ZoneServer.Packets.ZcItemPickupAckTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Packets.ZcItemPickupAck

  setup :setup_ets_tables

  describe "ZcItemPickupAck packet" do
    test "has correct packet id" do
      assert ZcItemPickupAck.packet_id() == 0x0A37
    end

    test "has correct packet size" do
      assert ZcItemPickupAck.packet_size() == 69
    end

    test "builds the 0x0A37 layout with resolved type and success result" do
      item = %InventoryItem{
        id: 7,
        nameid: 1101,
        amount: 1,
        equip: 2,
        identify: 1,
        attribute: 0,
        refine: 4,
        card0: 0,
        card1: 0,
        card2: 0,
        card3: 0,
        bound: 0,
        favorite: 0
      }

      # success/2 takes the server index and applies the +2 client offset
      packet = ZcItemPickupAck.success(item, 3)
      binary = ZcItemPickupAck.build(packet)

      assert byte_size(binary) == 69

      <<
        0x0A37::16-little,
        index::16-little,
        count::16-little,
        nameid::32-little,
        identify::8,
        attribute::8,
        refine::8,
        card0::32-little,
        card1::32-little,
        card2::32-little,
        card3::32-little,
        location::32-little,
        type::8,
        result::8,
        hire_expire::32-little,
        bind_on_equip::16-little,
        _options::binary-size(25),
        favorite::8,
        look::16-little
      >> = binary

      assert index == 5
      assert count == 1
      assert nameid == 1101
      assert identify == 1
      assert attribute == 0
      assert refine == 4
      assert card0 == 0
      assert card1 == 0
      assert card2 == 0
      assert card3 == 0
      assert location == 2
      # Sword resolves to IT_WEAPON (5), not a hardcoded 3
      assert type == 5
      assert result == ZcItemPickupAck.pickup_success()
      assert hire_expire == 0
      assert bind_on_equip == 0
      assert favorite == 0
      # look is resolved from the item db's view sprite
      {:ok, %{view: view}} = ItemManagement.get_item_by_id(1101)
      assert look == view
    end

    test "builds a failure ack with the given result code and zeroed item fields" do
      packet = ZcItemPickupAck.inventory_full(501)
      binary = ZcItemPickupAck.build(packet)

      assert byte_size(binary) == 69

      <<
        0x0A37::16-little,
        index::16-little,
        count::16-little,
        nameid::32-little,
        _identify::8,
        _attribute::8,
        _refine::8,
        _rest_before_result::binary-size(20),
        type::8,
        result::8,
        _rest::binary
      >> = binary

      assert index == 0
      assert count == 0
      assert nameid == 501
      assert type == 0
      assert result == ZcItemPickupAck.pickup_inventory_full()
    end
  end
end
