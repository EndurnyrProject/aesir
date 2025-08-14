defmodule Aesir.ZoneServer.Packets.ZcNotifyTime do
  @moduledoc """
  ZC_NOTIFY_TIME packet (0x007F) - Sends server time/tick to the client.

  This packet synchronizes the client with the server's time.

  Structure:
  - packet_type: 2 bytes (0x007F)
  - time: 4 bytes (server tick/time in milliseconds)

  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x007F
  @packet_size 6

  defstruct time: 0

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    # Use current system time in milliseconds if not specified
    time = if packet.time == 0, do: System.system_time(:millisecond), else: packet.time
    <<@packet_id::16-little, time::32-little>>
  end
end
