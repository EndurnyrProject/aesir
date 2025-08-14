defmodule Aesir.ZoneServer.Packets.ZcAid do
  @moduledoc """
  ZC_AID packet (0x0283) - Sends the account ID to the client.

  This packet informs the client of their account ID.

  Structure:
  - packet_type: 2 bytes (0x0283)
  - account_id: 4 bytes

  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0283
  @packet_size 6

  defstruct [:account_id]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    <<@packet_id::16-little, packet.account_id::32-little>>
  end
end
