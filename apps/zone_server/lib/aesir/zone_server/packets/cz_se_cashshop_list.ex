defmodule Aesir.ZoneServer.Packets.CzSeCashshopList do
  @moduledoc """
  CZ_SE_CASHSHOP_LIST packet (0x08C9) - Client requests cash shop item list.
  
  This packet is sent by the client when requesting the cash shop item list.
  The server should respond with the available cash shop items.
  
  Structure:
  - packet_type: 2 bytes (0x08C9)
  
  Total size: 2 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x08C9
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