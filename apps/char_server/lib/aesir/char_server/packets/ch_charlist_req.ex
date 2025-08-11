defmodule Aesir.CharServer.Packets.ChCharlistReq do
  @moduledoc """
  CH_CHARLIST_REQ packet (0x09A1) - Client requesting character list.

  This is sent by the client to request the character list again.
  The server responds with HC_ACK_CHARINFO_PER_PAGE (0x099d).

  Structure (2 bytes):
  - packet_id: 2 bytes (0x09A1)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x09A1
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

  @impl true
  def build(%__MODULE__{}) do
    <<@packet_id::16-little>>
  end
end
