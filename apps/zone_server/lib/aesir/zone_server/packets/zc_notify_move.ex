defmodule Aesir.ZoneServer.Packets.ZcNotifyMove do
  @moduledoc """
  ZC_NOTIFY_MOVE (0x0086) - Server notifies client of movement.

  Sent in response to CZ_REQUEST_MOVE to acknowledge the movement
  and provide the path to the destination.

  Structure:
  - packet_type: 2 bytes (0x0086)
  - server_tick: 4 bytes
  - move_data: 6 bytes (encoded source and destination positions)

  Total size: 12 bytes
  """
  use Aesir.Commons.Network.Packet
  import Bitwise

  @packet_id 0x0086
  @packet_size 12

  defstruct [:server_tick, :src_x, :src_y, :dst_x, :dst_y]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    server_tick = packet.server_tick || System.system_time(:millisecond)
    move_data = encode_move_data(packet.src_x, packet.src_y, packet.dst_x, packet.dst_y)

    <<@packet_id::16-little, server_tick::32-little, move_data::binary>>
  end

  @doc """
  Encodes source and destination positions into 6 bytes.

  The encoding packs two positions into 6 bytes:
  - byte0: x0 >> 2
  - byte1: (x0 << 6) | (y0 >> 4)
  - byte2: (y0 << 4) | (x1 >> 6)
  - byte3: (x1 << 2) | (y1 >> 8)
  - byte4: y1 & 0xFF
  - byte5: (sx0 << 4) | sy0 (cell offsets, we use 0)
  """
  def encode_move_data(x0, y0, x1, y1) do
    byte0 = x0 >>> 2
    byte1 = (x0 <<< 6 ||| (y0 >>> 4 &&& 0x3F)) &&& 0xFF
    byte2 = (y0 <<< 4 ||| (x1 >>> 6 &&& 0x0F)) &&& 0xFF
    byte3 = (x1 <<< 2 ||| (y1 >>> 8 &&& 0x03)) &&& 0xFF
    byte4 = y1 &&& 0xFF
    byte5 = 0

    <<byte0, byte1, byte2, byte3, byte4, byte5>>
  end
end
