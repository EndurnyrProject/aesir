defmodule Aesir.ZoneServer.Packets.ZcNotifyNewentry do
  @moduledoc """
  ZC_NOTIFY_NEWENTRY11 (0x09FE) - Shows a spawning/appearing unit to other players.

  This packet tells clients about another unit that is spawning or appearing.
  Used when a unit spawns, teleports in, or logs in to the view range.

  For latest PACKETVER (>= 20150513), packet ID is 0x09FE.
  This is a variable-length packet with appearance data.
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x09FE

  defstruct [
    :aid,
    :gid,
    :speed,
    :body_state,
    :health_state,
    :effect_state,
    :job,
    :head,
    :weapon,
    :shield,
    :accessory,
    :accessory2,
    :accessory3,
    :head_palette,
    :body_palette,
    :head_dir,
    :robe,
    :guild_id,
    :guild_emblem_ver,
    :honor,
    :virtue,
    :is_pk_mode_on,
    :sex,
    :x,
    :y,
    :dir,
    :x_size,
    :y_size,
    :clevel,
    :font,
    :max_hp,
    :hp,
    :is_boss,
    :body,
    :name
  ]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: :variable

  @impl true
  def build(%__MODULE__{} = packet) do
    # Encode position and direction (3 bytes)
    pos_dir = encode_pos_dir(packet.x, packet.y, packet.dir || 0)

    # Pack name with null terminator
    name_binary = pack_string(packet.name || "", 24)

    # Build the packet data (excluding header and length)
    data = <<
      # objecttype (1 byte) - 0 for player
      0::8,
      # AID and GID (8 bytes total)
      packet.aid::32-little,
      packet.gid::32-little,
      # Speed (2 bytes)
      packet.speed::16-little,
      # States (6 bytes total)
      packet.body_state::16-little,
      packet.health_state::16-little,
      packet.effect_state::32-little,
      # Job (2 bytes)
      packet.job::16-little,
      # Head (2 bytes)
      packet.head::16-little,
      # Weapon (4 bytes)
      packet.weapon::32-little,
      # Shield (4 bytes)
      packet.shield::32-little,
      # Accessory (2 bytes)
      packet.accessory::16-little,
      # Accessories 2 and 3 (4 bytes total)
      packet.accessory2::16-little,
      packet.accessory3::16-little,
      # Palettes (4 bytes total)
      packet.head_palette::16-little,
      packet.body_palette::16-little,
      # Head direction (2 bytes)
      packet.head_dir::16-little,
      # Robe (2 bytes)
      packet.robe::16-little,
      # Guild (8 bytes total)
      packet.guild_id::32-little,
      packet.guild_emblem_ver::16-little,
      # Honor (2 bytes)
      packet.honor::16-little,
      # Virtue (4 bytes)
      packet.virtue::32-little,
      # PK mode (1 byte)
      packet.is_pk_mode_on::8,
      # Sex (1 byte)
      packet.sex::8,
      # Position and direction (3 bytes)
      pos_dir::binary,
      # Sizes (2 bytes)
      packet.x_size::8,
      packet.y_size::8,
      # Level (2 bytes)
      packet.clevel::16-little,
      # Font (2 bytes)
      packet.font::16-little,
      # HP info (9 bytes total)
      packet.max_hp::32-little,
      packet.hp::32-little,
      packet.is_boss::8,
      # Body style (2 bytes)
      packet.body::16-little,
      # Name (24 bytes)
      name_binary::binary
    >>

    # Build variable-length packet with header and length
    build_variable_packet(@packet_id, data)
  end
end
