defmodule Aesir.CharServer.Packets.HcNotifyZonesvr.Test do
  use ExUnit.Case, async: true

  alias Aesir.CharServer.Packets.HcNotifyZonesvr

  @packet_id 0x0AC5
  @packet_size 156

  describe "packet_id/0" do
    test "returns 0x0AC5" do
      assert HcNotifyZonesvr.packet_id() == @packet_id
    end
  end

  describe "packet_size/0" do
    test "returns 156" do
      assert HcNotifyZonesvr.packet_size() == @packet_size
    end
  end

  describe "build/1" do
    setup do
      packet = %HcNotifyZonesvr{
        char_id: 150_000,
        map_name: "prontera.gat",
        ip: {127, 0, 0, 1},
        port: 5121
      }

      {:ok, packet: packet, binary: HcNotifyZonesvr.build(packet)}
    end

    test "produces exactly 156 bytes", %{binary: binary} do
      assert byte_size(binary) == @packet_size
    end

    test "begins with packet_id 0x0AC5 (little-endian)", %{binary: binary} do
      assert <<0xC5, 0x0A, _rest::binary>> = binary
    end

    test "encodes char_id at offset 2", %{binary: binary} do
      <<_header::16, char_id::32-little, _rest::binary>> = binary
      assert char_id == 150_000
    end

    test "map_name region is 16 bytes null-padded", %{binary: binary} do
      <<_header::16, _char_id::32, map_name_region::binary-size(16), _rest::binary>> = binary
      assert String.starts_with?(map_name_region, "prontera.gat")
    end

    test "ip bytes are 127, 0, 0, 1 at offset 22", %{binary: binary} do
      <<_header::16, _char_id::32, _map::binary-size(16), a::8, b::8, c::8, d::8, _rest::binary>> =
        binary

      assert {a, b, c, d} == {127, 0, 0, 1}
    end

    test "port decodes to 5121 (little-endian) at offset 26", %{binary: binary} do
      <<_header::16, _char_id::32, _map::binary-size(16), _ip::32, port::16-little,
        _rest::binary>> = binary

      assert port == 5121
    end

    test "last 128 bytes are all zero (empty domain)", %{binary: binary} do
      domain = binary_part(binary, @packet_size - 128, 128)
      assert domain == <<0::size(128 * 8)>>
    end
  end
end
