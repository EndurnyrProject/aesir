defmodule Aesir.AccountServer.Packets.AcAckHash do
  @moduledoc """
  AC_ACK_HASH packet (0x01DC) - Hash/seed value response from server.

  Variable-length packet structure:
  - packet_type: 2 bytes (0x01DC)
  - packet_length: 2 bytes
  - hash_value: variable binary data

  Minimum size: 4 bytes
  """
  use Aesir.Network.Packet

  @packet_id 0x01DC

  defstruct [:hash_value]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: :variable

  @impl true
  def build(%__MODULE__{} = packet) do
    data = packet.hash_value || <<>>
    build_variable_packet(@packet_id, data)
  end
end
