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

  @packet_id 0x0087
  @packet_size 12

  defstruct [:walk_start_time, :src_x, :src_y, :dst_x, :dst_y]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    walk_start_time = packet.walk_start_time
    walk_data = encode_move_data(packet.src_x, packet.src_y, packet.dst_x, packet.dst_y)

    <<@packet_id::16-little, walk_start_time::32-little, walk_data::binary>>
  end
end
