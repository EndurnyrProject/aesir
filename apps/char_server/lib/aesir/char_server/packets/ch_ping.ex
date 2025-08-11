defmodule Aesir.CharServer.Packets.ChPing do
  @moduledoc """
  CH_PING/Keepalive packet (0x0187) - Client keepalive.

  Sent by the client every 12 seconds to keep the connection alive.
  Contains the account ID but the server typically ignores it.

  Structure (6 bytes):
  - packet_id: 2 bytes (0x0187)
  - account_id: 4 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0187
  @packet_size 6

  defstruct [:account_id]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, account_id::32-little>>) do
    {:ok, %__MODULE__{account_id: account_id}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{account_id: account_id}) do
    <<@packet_id::16-little, account_id::32-little>>
  end
end
