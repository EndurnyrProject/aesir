defmodule Aesir.CharServer.Packets.HcRefuseEnter do
  @moduledoc """
  HC_REFUSE_ENTER packet (0x006c) - Character list refusal.

  Structure:
  - packet_type: 2 bytes (0x006c)
  - reason: 1 byte (refusal reason)

  Total size: 3 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x006C
  @packet_size 3

  defstruct [:reason]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{reason: reason}) do
    <<@packet_id::16-little, reason::8>>
  end
end
