defmodule Aesir.ZoneServer.Packets.ZcNotifyCastCancelTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.PacketRegistry
  alias Aesir.ZoneServer.Packets.ZcNotifyCastCancel

  describe "registration" do
    test "is registered in the packet registry" do
      assert PacketRegistry.get_module(0x01B9) == ZcNotifyCastCancel
    end
  end

  describe "packet metadata" do
    test "packet_id/0 is 0x01B9" do
      assert ZcNotifyCastCancel.packet_id() == 0x01B9
    end

    test "packet_size/0 is 6" do
      assert ZcNotifyCastCancel.packet_size() == 6
    end
  end

  describe "build/1" do
    test "encodes the gid in little-endian" do
      binary = ZcNotifyCastCancel.build(%ZcNotifyCastCancel{gid: 2_000_042})

      assert byte_size(binary) == 6
      assert binary == <<0x01B9::16-little, 2_000_042::32-little>>
    end
  end
end
