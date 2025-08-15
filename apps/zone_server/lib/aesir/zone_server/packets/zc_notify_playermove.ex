defmodule Aesir.ZoneServer.Packets.ZcNotifyPlayermove do
  @moduledoc """
  ZC_NOTIFY_PLAYERMOVE (0x0087) - Notifies the client that it is walking.
  
  This packet tells the client that their own character can start moving
  from source to destination.
  
  Structure:
  - packet_type: 2 bytes (0x0087)
  - walk_start_time: 4 bytes (server tick)
  - walk_data: 6 bytes (encoded source and destination positions)
  
  Total size: 12 bytes
  """
  use Aesir.Commons.Network.Packet
  import Bitwise

  @packet_id 0x0087
  @packet_size 12

  defstruct [:walk_start_time, :src_x, :src_y, :dst_x, :dst_y]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    walk_start_time = packet.walk_start_time || System.system_time(:millisecond)
    walk_data = encode_move_data(packet.src_x, packet.src_y, packet.dst_x, packet.dst_y)
    
    <<@packet_id::16-little, walk_start_time::32-little, walk_data::binary>>
  end

  @doc """
  Encodes source and destination positions into 6 bytes.
  Based on WBUFPOS2 from rAthena.
  
  The encoding packs two positions into 6 bytes with 8,8 as cell offsets:
  - byte0: x0 >> 2
  - byte1: (x0 << 6) | (y0 >> 4)
  - byte2: (y0 << 4) | (x1 >> 6)
  - byte3: (x1 << 2) | (y1 >> 8)
  - byte4: y1 & 0xFF
  - byte5: (sx0 << 4) | sy0 (cell offsets, using 8,8 as per rAthena)
  """
  def encode_move_data(x0, y0, x1, y1) do
    byte0 = x0 >>> 2
    byte1 = ((x0 <<< 6) ||| ((y0 >>> 4) &&& 0x3F)) &&& 0xFF
    byte2 = ((y0 <<< 4) ||| ((x1 >>> 6) &&& 0x0F)) &&& 0xFF
    byte3 = ((x1 <<< 2) ||| ((y1 >>> 8) &&& 0x03)) &&& 0xFF
    byte4 = y1 &&& 0xFF
    byte5 = (8 <<< 4) ||| 8  # sx0=8, sy0=8 as per rAthena
    
    <<byte0, byte1, byte2, byte3, byte4, byte5>>
  end
end