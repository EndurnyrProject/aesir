defmodule Aesir.ZoneServer.Packets.ZcNotifyTime do
  @moduledoc """
  ZC_NOTIFY_TIME packet (0x007F) - Server responds with its tick/timestamp.
  
  This packet is sent in response to CZ_REQUEST_TIME (0x0360).
  
  Structure:
  - packet_type: 2 bytes (0x007F)
  - server_tick: 4 bytes
  
  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x007F
  @packet_size 6

  defstruct [:server_tick]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{server_tick: server_tick}) do
    <<@packet_id::16-little, server_tick::32-little>>
  end
end