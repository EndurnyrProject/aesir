defmodule Aesir.ZoneServer.Packets.ZcAckReqname do
  @moduledoc """
  ZC_ACK_REQNAME packet (0x0095) - Server response with character name.

  Sent in response to CZ_REQNAME2 (0x0368) to provide the character's name.

  Structure:
  - packet_type: 2 bytes (0x0095)
  - char_id: 4 bytes (character/account ID)
  - name: 24 bytes (character name, null-padded)

  Total size: 30 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0095
  @packet_size 30
  @name_length 24

  defstruct [:char_id, :name]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{char_id: char_id, name: name}) do
    # Pad the name to 24 bytes with null characters
    padded_name = String.pad_trailing(name || "", @name_length, <<0>>)

    <<@packet_id::16-little, char_id::32-little, padded_name::binary-size(@name_length)>>
  end
end
