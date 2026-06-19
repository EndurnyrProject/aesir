defmodule Aesir.ZoneServer.Packets.ZcInventoryItemlistNormalTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Packets.ZcInventoryItemlistNormal

  setup :setup_ets_tables

  describe "ZcInventoryItemlistNormal packet" do
    test "has correct packet id" do
      assert ZcInventoryItemlistNormal.packet_id() == 0x0B09
    end

    test "is a variable-size packet" do
      assert ZcInventoryItemlistNormal.packet_size() == :variable
    end

    test "builds an empty list with just the header" do
      packet = ZcInventoryItemlistNormal.from_inventory(%{})
      binary = ZcInventoryItemlistNormal.build(packet)

      assert <<0x0B09::16-little, length::16-little, 0::8>> = binary
      assert length == byte_size(binary)
      assert length == 5
    end

    test "only includes non-equipped items, applying the +2 client offset and resolving type" do
      # index 0 -> Red Potion (healing, type 0); index 1 -> Sword (equipped, excluded)
      inventory = %{
        0 => %InventoryItem{id: 1, nameid: 501, amount: 5, equip: 0, identify: 1},
        1 => %InventoryItem{id: 2, nameid: 1101, amount: 1, equip: 2, identify: 1}
      }

      packet = ZcInventoryItemlistNormal.from_inventory(inventory)
      binary = ZcInventoryItemlistNormal.build(packet)

      <<0x0B09::16-little, length::16-little, 0::8, items::binary>> = binary
      assert length == byte_size(binary)

      <<
        index::16-little,
        nameid::32-little,
        type::8,
        amount::16-little,
        _wear_state::32-little,
        _card0::32-little,
        _card1::32-little,
        _card2::32-little,
        _card3::32-little,
        _expire::32-little,
        flag::8
      >> = items

      # client index is server index 0 + 2
      assert index == 2
      assert nameid == 501
      # healing resolves to IT_HEALING (0), not a hardcoded 3
      assert type == 0
      assert amount == 5
      # identified flag in bit 0
      assert Bitwise.band(flag, 1) == 1
    end
  end
end
