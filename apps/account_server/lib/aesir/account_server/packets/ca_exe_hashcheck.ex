defmodule Aesir.AccountServer.Packets.CaExeHashcheck do
  @moduledoc """
  CA_EXE_HASHCHECK packet (0x0204) - Client sends hash calculation result.

  Fixed-size packet structure:
  - packet_type: 2 bytes (0x0204)
  - hash_value: 16 bytes (MD5 hash)

  Total size: 18 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0204
  @packet_size 18

  defstruct [:hash_value]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, hash_value::binary-size(16)>>) do
    {:ok, %__MODULE__{hash_value: hash_value}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
