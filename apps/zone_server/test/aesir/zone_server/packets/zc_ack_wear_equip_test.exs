defmodule Aesir.ZoneServer.Packets.ZcAckWearEquipTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcAckWearEquip

  describe "ZcAckWearEquip packet" do
    test "has correct packet id" do
      assert ZcAckWearEquip.packet_id() == 0x0999
    end

    test "has correct packet size" do
      assert ZcAckWearEquip.packet_size() == 11
    end

    test "builds a success layout with u32 location and view id" do
      packet = ZcAckWearEquip.success(3, 2, 1101)
      binary = ZcAckWearEquip.build(packet)

      assert byte_size(binary) == 11

      <<
        0x0999::16-little,
        index::16-little,
        location::32-little,
        view_id::16-little,
        result::8
      >> = binary

      # success/3 applies the +2 client offset to the server index
      assert index == 5
      assert location == 2
      assert view_id == 1101
      assert result == ZcAckWearEquip.result_ok()
    end

    test "builds failure variants with the documented result codes" do
      level_binary = 1 |> ZcAckWearEquip.failure(:level) |> ZcAckWearEquip.build()

      <<0x0999::16-little, _index::16-little, _loc::32-little, _view::16-little, level::8>> =
        level_binary

      fail_binary = 1 |> ZcAckWearEquip.failure(:fail) |> ZcAckWearEquip.build()
      <<0x0999::16-little, _i::16-little, _l::32-little, _v::16-little, fail::8>> = fail_binary

      assert level == ZcAckWearEquip.result_fail_level()
      assert fail == ZcAckWearEquip.result_fail()
    end

    test "exposes the result codes" do
      assert ZcAckWearEquip.result_ok() == 0
      assert ZcAckWearEquip.result_fail_level() == 1
      assert ZcAckWearEquip.result_fail() == 2
    end
  end
end
