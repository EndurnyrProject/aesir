defmodule Aesir.CharServer.Packets.HcAcceptMakechar do
  @moduledoc """
  HC_ACCEPT_MAKECHAR packet (0x0B6F) - Character creation success.

  Structure:
  - packet_type: 2 bytes (0x0B6F)
  - character_data: 175 bytes (extended character data)

  Total: 177 bytes
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.CharServer.Packets.CharacterInfo

  @packet_id 0x0B6F
  @packet_size 177

  defstruct [:character_data]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{character_data: character}) do
    <<@packet_id::16-little, CharacterInfo.serialize(character)::binary>>
  end
end
