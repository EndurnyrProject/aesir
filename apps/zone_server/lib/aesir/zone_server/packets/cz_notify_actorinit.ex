defmodule Aesir.ZoneServer.Packets.CzNotifyActorinit do
  @moduledoc """
  CZ_NOTIFY_ACTORINIT packet (0x007D) - Client notifies that map loading is complete.

  This packet is sent by the client after it finishes loading the map data.
  The server should respond with character spawn data, inventory, skills, etc.

  Structure:
  - packet_type: 2 bytes (0x007D)

  Total size: 2 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x007D
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
