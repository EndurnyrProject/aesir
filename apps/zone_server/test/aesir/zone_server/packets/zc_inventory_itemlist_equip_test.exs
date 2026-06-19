defmodule Aesir.ZoneServer.Packets.ZcInventoryItemlistEquipTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Packets.ZcInventoryItemlistEquip

  setup :setup_ets_tables

  describe "ZcInventoryItemlistEquip packet" do
    test "has correct packet id" do
      assert ZcInventoryItemlistEquip.packet_id() == 0x0B0A
    end

    test "is a variable-size packet" do
      assert ZcInventoryItemlistEquip.packet_size() == :variable
    end

    test "builds an empty list with just the header" do
      packet = ZcInventoryItemlistEquip.from_inventory(%{})
      binary = ZcInventoryItemlistEquip.build(packet)

      assert <<0x0B0A::16-little, length::16-little, 0::8>> = binary
      assert length == byte_size(binary)
      assert length == 5
    end

    test "only includes equipped items, with location matching the worn bitmask" do
      # index 0 -> Red Potion (not equipped, excluded); index 1 -> Sword (right hand = 2)
      inventory = %{
        0 => %InventoryItem{id: 1, nameid: 501, amount: 5, equip: 0, identify: 1},
        1 => %InventoryItem{id: 2, nameid: 1101, amount: 1, equip: 2, refine: 4, identify: 1}
      }

      packet = ZcInventoryItemlistEquip.from_inventory(inventory)
      binary = ZcInventoryItemlistEquip.build(packet)

      <<0x0B0A::16-little, length::16-little, 0::8, items::binary>> = binary
      assert length == byte_size(binary)

      <<
        index::16-little,
        nameid::32-little,
        type::8,
        location::32-little,
        wear_state::32-little,
        refine::8,
        _card0::32-little,
        _card1::32-little,
        _card2::32-little,
        _card3::32-little,
        _expire::32-little,
        _bind_on_equip::16-little,
        _sprite::16-little,
        option_count::8,
        _options::binary-size(25),
        flag::8
      >> = items

      # only the equipped sword, at client index 1 + 2 = 3
      assert index == 3
      assert nameid == 1101
      # weapon resolves to IT_WEAPON (5), not a hardcoded 3
      assert type == 5
      # location and wear-state both reflect the worn bitmask
      assert location == 2
      assert wear_state == 2
      assert refine == 4
      assert option_count == 0
      assert Bitwise.band(flag, 1) == 1
    end
  end
end
