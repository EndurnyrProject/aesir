defmodule Aesir.CharServer.Packets.ChSelectChar do
  @moduledoc """
  CH_SELECT_CHAR packet (0x0066) - Client selects character.

  Structure:
  - packet_type: 2 bytes (0x0066)
  - slot: 1 byte (character slot number)

  Total size: 3 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0066
  @packet_size 3

  defstruct [:slot]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, data::binary>>) do
    parse(data)
  end

  def parse(<<slot::8>>) do
    {:ok, %__MODULE__{slot: slot}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
