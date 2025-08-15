defmodule Aesir.ZoneServer.Packets.CzPingLive do
  @moduledoc """
  CZ_PING_LIVE packet (0x0B1C) - Client ping/keepalive packet.

  This packet is sent periodically by the client to keep the connection alive.
  The server should respond with ZC_PING_LIVE (0x0B1D).

  Structure:
  - packet_type: 2 bytes (0x0B1C)

  Total size: 2 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0B1C
  @packet_size 2

  defstruct []

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little>>) do
    {:ok, %__MODULE__{}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
