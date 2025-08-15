defmodule Aesir.ZoneServer.Packets.CzRequestTime do
  @moduledoc """
  CZ_REQUEST_TIME packet (0x007E) - Client sends its tick/timestamp.

  This packet is sent periodically by the client with its current tick.
  The server should respond with ZC_NOTIFY_TIME.

  Structure:
  - packet_type: 2 bytes (0x007E)
  - client_tick: 4 bytes

  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x007E
  @packet_size 6

  defstruct [:client_tick]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, client_tick::32-little>>) do
    {:ok, %__MODULE__{client_tick: client_tick}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
