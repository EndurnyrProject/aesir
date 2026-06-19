defmodule Aesir.ZoneServer.Packets.CzReqWearEquipTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzReqWearEquip

  describe "parse/1" do
    test "parses valid equip request with index and position" do
      index = 10
      position = 0x0002

      packet_data = <<0x0998::16-little, index::16-little, position::32-little>>

      assert {:ok, packet} = CzReqWearEquip.parse(packet_data)
      assert packet.index == index
      assert packet.position == position
    end

    test "parses right-hand weapon request" do
      index = 3
      position = 2

      packet_data = <<0x0998::16-little, index::16-little, position::32-little>>

      assert {:ok, %CzReqWearEquip{index: 3, position: 2}} = CzReqWearEquip.parse(packet_data)
    end

    test "parses armor request with large position bitmask" do
      index = 7
      position = 16

      packet_data = <<0x0998::16-little, index::16-little, position::32-little>>

      assert {:ok, packet} = CzReqWearEquip.parse(packet_data)
      assert packet.index == index
      assert packet.position == position
    end

    test "returns error for truncated packet" do
      truncated = <<0x0998::16-little, 10::16-little>>
      assert {:error, :invalid_packet} = CzReqWearEquip.parse(truncated)
    end

    test "returns error for wrong packet id" do
      wrong_id = <<0x0001::16-little, 10::16-little, 2::32-little>>
      assert {:error, :invalid_packet} = CzReqWearEquip.parse(wrong_id)
    end

    test "returns error for empty binary" do
      assert {:error, :invalid_packet} = CzReqWearEquip.parse(<<>>)
    end
  end

  describe "packet info" do
    test "has correct packet id" do
      assert CzReqWearEquip.packet_id() == 0x0998
    end

    test "has correct packet size" do
      assert CzReqWearEquip.packet_size() == 8
    end
  end
end
