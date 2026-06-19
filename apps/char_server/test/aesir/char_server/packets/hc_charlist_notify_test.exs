defmodule Aesir.CharServer.Packets.HcCharlistNotifyTest do
  use ExUnit.Case, async: true

  alias Aesir.CharServer.Packets.HcCharlistNotify

  describe "packet metadata" do
    test "packet_id is 0x09A0" do
      assert HcCharlistNotify.packet_id() == 0x09A0
    end

    test "packet_size is 6 (latest layout: header + total)" do
      assert HcCharlistNotify.packet_size() == 6
    end
  end

  describe "build/1" do
    test "emits the 6-byte header + page count" do
      packet = HcCharlistNotify.build(%HcCharlistNotify{char_slots: 9})

      assert byte_size(packet) == 6
      assert <<0x09A0::16-little, total::32-little>> = packet
      assert total == 3
    end

    test "page count is max(char_slots / 3, 1)" do
      assert <<0x09A0::16-little, 5::32-little>> =
               HcCharlistNotify.build(%HcCharlistNotify{char_slots: 15})

      assert <<0x09A0::16-little, 1::32-little>> =
               HcCharlistNotify.build(%HcCharlistNotify{char_slots: 2})
    end
  end
end
