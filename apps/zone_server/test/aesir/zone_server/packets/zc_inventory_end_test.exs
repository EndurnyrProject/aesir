defmodule Aesir.ZoneServer.Packets.ZcInventoryEndTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcInventoryEnd

  describe "ZcInventoryEnd packet" do
    test "has correct packet id" do
      assert ZcInventoryEnd.packet_id() == 0x0B0B
    end

    test "has a fixed size of 4 bytes" do
      assert ZcInventoryEnd.packet_size() == 4
    end

    test "builds a binary carrying inv type and flag" do
      binary = ZcInventoryEnd.build(%ZcInventoryEnd{inv_type: 0, flag: 0})

      assert byte_size(binary) == 4
      assert <<0x0B0B::16-little, 0::8, 0::8>> = binary
    end

    test "defaults to normal inventory type with a clear flag" do
      assert <<0x0B0B::16-little, 0::8, 0::8>> = ZcInventoryEnd.build(%ZcInventoryEnd{})
    end
  end
end
