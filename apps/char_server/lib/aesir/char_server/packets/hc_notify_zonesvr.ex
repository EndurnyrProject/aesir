defmodule Aesir.CharServer.Packets.HcNotifyZonesvr do
  @moduledoc """
  HC_NOTIFY_ZONESVR packet (0x0AC5) — zone server handoff (PACKETVER >= 20170315).

  Structure:
  - packet_type: 2 bytes (0x0AC5, little-endian)
  - CID: 4 bytes (character ID, little-endian)
  - mapname: 16 bytes (null-padded map name)
  - ip: 4 bytes (zone server IP, 4 raw octets)
  - port: 2 bytes (zone server port, little-endian)
  - domain: 128 bytes (always empty — rAthena always sends zeroes)

  Total size: 156 bytes

  The `domain` field is always 128 zero bytes. rAthena source `char_clif.cpp:912`
  always calls `safestrncpy(p.domain, "", sizeof(p.domain))`, so it is not exposed
  as a struct field.
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0AC5
  @packet_size 156

  defstruct [:char_id, :map_name, :ip, :port]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{char_id: char_id, map_name: map_name, ip: {a, b, c, d}, port: port}) do
    map_name_packed = pack_string(map_name, 16)

    <<@packet_id::16-little, char_id::32-little, map_name_packed::binary, a::8, b::8, c::8, d::8,
      port::16-little, 0::size(128 * 8)>>
  end
end
