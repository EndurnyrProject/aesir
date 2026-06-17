defmodule Aesir.ZoneServer.Packets.ZcBlownbackTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcBlownback

  describe "ZcBlownback packet" do
    test "has correct packet id" do
      assert ZcBlownback.packet_id() == 0x01B1
    end

    test "has correct packet size" do
      assert ZcBlownback.packet_size() == 10
    end

    test "builds and parses back round-trip" do
      packet = %ZcBlownback{unit_id: 12_345, dst_x: 150, dst_y: 200}

      binary = ZcBlownback.build(packet)

      assert byte_size(binary) == 10

      assert {:ok, %ZcBlownback{unit_id: 12_345, dst_x: 150, dst_y: 200}} =
               ZcBlownback.parse(binary)
    end
  end
end
