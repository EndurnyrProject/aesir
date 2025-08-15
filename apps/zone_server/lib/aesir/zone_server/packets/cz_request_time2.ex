defmodule Aesir.ZoneServer.Packets.CzRequestTime2 do
  @moduledoc """
  CZ_REQUEST_TIME2 (0x0360) - Client requests server time.
  
  The client periodically sends this to sync time with the server.
  
  Structure:
  - packet_type: 2 bytes (0x0360)
  - client_time: 4 bytes
  
  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0360
  @packet_size 6

  defstruct [:client_time]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, client_time::32-little>>) do
    {:ok,
     %__MODULE__{
       client_time: client_time
     }}
  end

  def parse(_), do: {:error, :invalid_packet}
end