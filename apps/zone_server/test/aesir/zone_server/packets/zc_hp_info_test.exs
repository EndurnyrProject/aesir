defmodule Aesir.ZoneServer.Packets.ZcHpInfoTest do
  use ExUnit.Case

  alias Aesir.ZoneServer.Packets.ZcHpInfo

  describe "ZcHpInfo packet" do
    test "has correct packet id" do
      assert ZcHpInfo.packet_id() == 0x0977
    end

    test "has correct packet size" do
      assert ZcHpInfo.packet_size() == 14
    end

    test "creates packet with new/3" do
      packet = ZcHpInfo.new(12_345, 500, 1000)

      assert packet.id == 12_345
      assert packet.hp == 500
      assert packet.max_hp == 1000
    end

    test "ensures HP cannot be negative" do
      packet = ZcHpInfo.new(12_345, -100, 1000)

      assert packet.hp == 0
    end

    test "ensures max HP is at least 1" do
      packet = ZcHpInfo.new(12_345, 500, 0)

      assert packet.max_hp == 1
    end

    test "builds binary packet correctly" do
      packet = ZcHpInfo.new(12_345, 500, 1000)
      binary = ZcHpInfo.build(packet)

      # Packet should be 14 bytes total (2 bytes header + 12 bytes data)
      assert byte_size(binary) == 14

      # Check packet header (0x0977)
      <<packet_id::16-little, rest::binary>> = binary
      assert packet_id == 0x0977

      # Check packet data (4 + 4 + 4 = 12 bytes data)
      <<id::32-little, hp::32-little, max_hp::32-little>> = rest
      assert id == 12_345
      assert hp == 500
      assert max_hp == 1000
    end

    test "handles large HP values" do
      packet = ZcHpInfo.new(999_999, 2_000_000_000, 2_000_000_000)
      binary = ZcHpInfo.build(packet)

      <<_packet_id::16-little, id::32-little, hp::32-little, max_hp::32-little>> = binary
      assert id == 999_999
      assert hp == 2_000_000_000
      assert max_hp == 2_000_000_000
    end
  end
end
