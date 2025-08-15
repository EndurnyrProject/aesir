defmodule Aesir.ZoneServer.Packets.ZcNotifyMoveStop do
  @moduledoc """
  ZC_NOTIFY_MOVE_STOP (0x0088) - Server notifies client to stop movement.
  
  Sent when the server needs to stop a player's movement, either because
  they reached their destination or movement was interrupted.
  
  Structure:
  - packet_type: 2 bytes (0x0088)
  - account_id: 4 bytes
  - x: 2 bytes
  - y: 2 bytes
  
  Total size: 10 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0088
  @packet_size 10

  defstruct [:account_id, :x, :y]

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
    <<@packet_id::16-little, packet.account_id::32-little, packet.x::16-little,
      packet.y::16-little>>
  end
end