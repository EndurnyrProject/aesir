defmodule Aesir.ZoneServer.Packets.CzReqname2 do
  @moduledoc """
  CZ_REQNAME2 packet (0x0368) - Client requesting character name for a given ID.
  
  This is typically sent when the client needs to display a character's name
  (e.g., when hovering over them or when they come into view).
  
  Structure:
  - packet_type: 2 bytes (0x0368)
  - char_id: 4 bytes
  
  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0368
  @packet_size 6

  defstruct [:char_id]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, char_id::32-little>>) do
    {:ok, %__MODULE__{char_id: char_id}}
  end

  def parse(_), do: {:error, :invalid_packet}
end