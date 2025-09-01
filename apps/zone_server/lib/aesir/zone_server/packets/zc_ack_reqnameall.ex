defmodule Aesir.ZoneServer.Packets.ZcAckReqnameall do
  @moduledoc """
  ZC_ACK_REQNAMEALL packet (0x0195) - Server response with character name and party/guild info.

  Sent in response to CZ_REQNAME2 (0x0368) to provide complete character information.

  Structure (like rAthena PACKET_ZC_ACK_REQNAMEALL):
  - packet_id: 2 bytes (0x0195)
  - gid: 4 bytes (character ID)
  - name: 24 bytes (character name, null-padded)
  - party_name: 24 bytes (party name, null-padded)
  - guild_name: 24 bytes (guild name, null-padded)
  - position_name: 24 bytes (guild position, null-padded)

  Total size: 102 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0195
  @packet_size 102
  @name_length 24

  defstruct [:gid, :name, :party_name, :guild_name, :position_name]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    # Use pack_string to create fixed 24-byte null-terminated strings
    name = pack_string(packet.name || "", @name_length)
    party_name = pack_string(packet.party_name || "", @name_length)
    guild_name = pack_string(packet.guild_name || "", @name_length)
    position_name = pack_string(packet.position_name || "", @name_length)

    <<@packet_id::16-little, packet.gid::32-little, name::binary, party_name::binary,
      guild_name::binary, position_name::binary>>
  end
end
