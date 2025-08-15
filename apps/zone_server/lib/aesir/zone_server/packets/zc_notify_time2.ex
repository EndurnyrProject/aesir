defmodule Aesir.ZoneServer.Packets.ZcNotifyTime2 do
  @moduledoc """
  ZC_NOTIFY_TIME2 (0x02C2) - Server responds with current time.

  Sent in response to CZ_REQUEST_TIME2 to sync time.

  Structure:
  - packet_type: 2 bytes (0x02C2)
  - time: 4 bytes (server time in milliseconds)

  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x02C2
  @packet_size 6

  defstruct [:time]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(_data) do
    # This is a server->client packet, we don't parse it
    {:error, :not_implemented}
  end

  @impl true
  def build(%__MODULE__{} = packet) do
    time = packet.time || System.system_time(:millisecond)
    <<@packet_id::16-little, time::32-little>>
  end
end
