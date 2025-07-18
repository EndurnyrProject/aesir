defmodule Aesir.CharServer.Packets.HcDeleteChar do
  @moduledoc """
  HC_DELETE_CHAR packet (0x006f) - Character deletion response.

  Structure:
  - packet_type: 2 bytes (0x006f)
  - result: 1 byte (0 = success, 1 = failure)

  Total size: 3 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x006F
  @packet_size 3

  defstruct [:result]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{result: result}) do
    <<@packet_id::16-little, result::8>>
  end
end
