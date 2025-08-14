defmodule Aesir.ZoneServer.Packets.ZcAcceptEnter do
  @moduledoc """
  ZC_ACCEPT_ENTER2 packet (0x02EB) - Server accepts client's connection to the zone.

  This is the first packet sent after validating CZ_ENTER.
  It confirms the connection and provides initial position data.

  Structure:
  - packet_type: 2 bytes (0x02EB)
  - start_time: 4 bytes (server tick)
  - pos_dir: 3 bytes (position and direction)
  - x_size: 1 byte (ignored, usually 5)
  - y_size: 1 byte (ignored, usually 5)
  - font: 2 bytes (character font, usually 0)

  Total size: 13 bytes
  """
  use Aesir.Commons.Network.Packet
  import Bitwise

  @packet_id 0x02EB
  @packet_size 13

  defstruct start_time: 0,
            x: 50,
            y: 50,
            dir: 0,
            font: 0

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    pos_dir = encode_position(packet.x, packet.y, packet.dir)

    <<@packet_id::16-little, packet.start_time::32-little, pos_dir::binary-size(3), 5::8, 5::8,
      packet.font::16-little>>
  end

  defp encode_position(x, y, dir) do
    # Pack position and direction into 3 bytes
    # Format: 10 bits for X, 10 bits for Y, 4 bits for direction
    value = (x &&& 0x3FF) ||| (y &&& 0x3FF) <<< 10 ||| (dir &&& 0x0F) <<< 20
    <<value::24-little>>
  end
end
