defmodule Aesir.ZoneServer.Packets.CzReqTakeoffEquipTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzReqTakeoffEquip

  describe "parse/1" do
    test "parses valid unequip request" do
      index = 5

      packet_data = <<0x00AB::16-little, index::16-little>>

      assert {:ok, packet} = CzReqTakeoffEquip.parse(packet_data)
      assert packet.index == index
    end

    test "parses unequip request for another index" do
      index = 42

      packet_data = <<0x00AB::16-little, index::16-little>>

      assert {:ok, %CzReqTakeoffEquip{index: 42}} = CzReqTakeoffEquip.parse(packet_data)
    end

    test "returns error for truncated packet" do
      truncated = <<0x00AB::16-little>>
      assert {:error, :invalid_packet} = CzReqTakeoffEquip.parse(truncated)
    end

    test "returns error for wrong packet id" do
      wrong_id = <<0x0001::16-little, 5::16-little>>
      assert {:error, :invalid_packet} = CzReqTakeoffEquip.parse(wrong_id)
    end

    test "returns error for empty binary" do
      assert {:error, :invalid_packet} = CzReqTakeoffEquip.parse(<<>>)
    end

    test "returns error for packet with trailing bytes" do
      extra_bytes = <<0x00AB::16-little, 5::16-little, 0xFF>>
      assert {:error, :invalid_packet} = CzReqTakeoffEquip.parse(extra_bytes)
    end
  end

  describe "packet info" do
    test "has correct packet id" do
      assert CzReqTakeoffEquip.packet_id() == 0x00AB
    end

    test "has correct packet size" do
      assert CzReqTakeoffEquip.packet_size() == 4
    end
  end
end
