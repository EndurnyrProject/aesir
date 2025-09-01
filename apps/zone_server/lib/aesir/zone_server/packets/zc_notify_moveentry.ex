defmodule Aesir.ZoneServer.Packets.ZcNotifyMoveentry do
  @moduledoc """
  ZC_NOTIFY_MOVEENTRY (0x09FD) - Shows a walking unit to other players.

  This packet tells clients about another unit that is currently walking.
  Used when a player enters the view range while walking.

  For latest PACKETVER (>= 20150513), packet ID is 0x09FD.
  This is a variable-length packet with appearance and movement data.
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Utils

  @packet_id 0x09FD

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
    :move_start_time,
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
    :src_x,
    :src_y,
    :dst_x,
    :dst_y,
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
    # Encode movement data (6 bytes)
    move_data = encode_move_data(packet.src_x, packet.src_y, packet.dst_x, packet.dst_y)

    # Pack name with null terminator
    name_binary = pack_string(Utils.get_field(packet.name, ""), 24)

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
      # Move start time (4 bytes)
      packet.move_start_time::32-little,
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
      # Movement data (6 bytes)
      move_data::binary,
      # Sizes (2 bytes)
      Utils.get_field(packet.x_size, 0)::8,
      Utils.get_field(packet.y_size, 0)::8,
      # Level (2 bytes)
      Utils.get_field(packet.clevel, 1)::16-little,
      # Font (2 bytes)
      Utils.get_field(packet.font, 0)::16-little,
      # HP info (9 bytes total)
      Utils.get_field(packet.max_hp, 0)::32-little,
      Utils.get_field(packet.hp, 0)::32-little,
      Utils.get_field(packet.is_boss, 0)::8,
      # Body style (2 bytes)
      Utils.get_field(packet.body, 0)::16-little,
      # Name (24 bytes)
      name_binary::binary
    >>

    # Build variable-length packet with header and length
    build_variable_packet(@packet_id, data)
  end
end
