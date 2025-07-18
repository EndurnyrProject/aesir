defmodule Aesir.CharServer.Packets.HcNotifyZonesvr do
  @moduledoc """
  HC_NOTIFY_ZONESVR packet (0x0071) - Zone server information.

  Structure:
  - packet_type: 2 bytes (0x0071)
  - char_id: 4 bytes (character ID)
  - map_name: 16 bytes (map name)
  - ip: 4 bytes (zone server IP)
  - port: 2 bytes (zone server port)

  Total size: 28 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0071
  @packet_size 28

  defstruct [:char_id, :map_name, :ip, :port]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{char_id: char_id, map_name: map_name, ip: {a, b, c, d}, port: port}) do
    map_name_packed = pack_string(map_name, 16)

    <<@packet_id::16-little, char_id::32-little, map_name_packed::binary, a::8, b::8, c::8, d::8,
      port::16-little>>
  end
end
