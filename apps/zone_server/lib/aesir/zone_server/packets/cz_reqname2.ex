defmodule Aesir.ZoneServer.Packets.CzReqname2 do
  @moduledoc """
  CZ_REQNAME2 packet (0x0368) - Client requesting entity name for a given ID.

  This is sent when the client needs to display an entity's name
  (players, mobs, NPCs, pets, etc.) when hovering over them or when they come into view.

  The response depends on the entity type:
  - Players: ZC_ACK_REQNAMEALL (0x0195) with party/guild info
  - Mobs/NPCs/Pets: ZC_ACK_REQNAME (0x0095) with just the name

  Structure:
  - packet_type: 2 bytes (0x0368)
  - entity_id: 4 bytes (char_id for players, mob_id for mobs, etc.)

  Total size: 6 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0368
  @packet_size 6

  defstruct [:entity_id]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, entity_id::32-little>>) do
    {:ok, %__MODULE__{entity_id: entity_id}}
  end

  def parse(_), do: {:error, :invalid_packet}
end
