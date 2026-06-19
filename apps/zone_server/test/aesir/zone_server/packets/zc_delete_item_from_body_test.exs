defmodule Aesir.ZoneServer.Packets.ZcDeleteItemFromBodyTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcDeleteItemFromBody

  describe "ZcDeleteItemFromBody packet" do
    test "has correct packet id" do
      assert ZcDeleteItemFromBody.packet_id() == 0x07FA
    end

    test "has correct packet size" do
      assert ZcDeleteItemFromBody.packet_size() == 8
    end

    test "builds the layout with reason, client index, and amount" do
      packet = ZcDeleteItemFromBody.new(3, 2, ZcDeleteItemFromBody.reason_normal())
      binary = ZcDeleteItemFromBody.build(packet)

      assert byte_size(binary) == 8

      <<0x07FA::16-little, reason::16-little, index::16-little, amount::16-little>> = binary

      # new/3 applies the +2 client offset to the server index
      assert reason == ZcDeleteItemFromBody.reason_normal()
      assert index == 5
      assert amount == 2
    end

    test "exposes the documented reason codes" do
      assert ZcDeleteItemFromBody.reason_normal() == 0
      assert ZcDeleteItemFromBody.reason_skill() == 1
      assert ZcDeleteItemFromBody.reason_refine_failed() == 2
      assert ZcDeleteItemFromBody.reason_material_changed() == 3
      assert ZcDeleteItemFromBody.reason_moved_to_storage() == 4
      assert ZcDeleteItemFromBody.reason_moved_to_cart() == 5
      assert ZcDeleteItemFromBody.reason_sold() == 6
      assert ZcDeleteItemFromBody.reason_analysis() == 7
    end
  end
end
