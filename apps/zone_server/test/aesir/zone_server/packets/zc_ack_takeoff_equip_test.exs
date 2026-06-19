defmodule Aesir.ZoneServer.Packets.ZcAckTakeoffEquipTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcAckTakeoffEquip

  describe "ZcAckTakeoffEquip packet" do
    test "has correct packet id" do
      assert ZcAckTakeoffEquip.packet_id() == 0x099A
    end

    test "has correct packet size" do
      assert ZcAckTakeoffEquip.packet_size() == 9
    end

    test "builds a success layout with u32 location and inverted result" do
      packet = ZcAckTakeoffEquip.success(3, 2)
      binary = ZcAckTakeoffEquip.build(packet)

      assert byte_size(binary) == 9

      <<0x099A::16-little, index::16-little, location::32-little, result::8>> = binary

      # success/2 applies the +2 client offset to the server index
      assert index == 5
      assert location == 2
      # the V5 takeoff ack inverts the flag: 0 = success
      assert result == ZcAckTakeoffEquip.result_success()
    end

    test "builds a failure layout" do
      binary = 3 |> ZcAckTakeoffEquip.failure() |> ZcAckTakeoffEquip.build()

      <<0x099A::16-little, _index::16-little, _location::32-little, result::8>> = binary
      assert result == ZcAckTakeoffEquip.result_failure()
    end

    test "exposes the inverted result codes" do
      assert ZcAckTakeoffEquip.result_success() == 0
      assert ZcAckTakeoffEquip.result_failure() == 1
    end
  end
end
