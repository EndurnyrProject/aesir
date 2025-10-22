defmodule Aesir.ZoneServer.Packets.ZcNotifyMoveentry do
  @moduledoc """
  ZC_NOTIFY_MOVEENTRY (0x09FD) - Shows a walking unit to other players.

  This packet tells clients about another unit that is currently walking.
  Used when a unit enters the view range while walking.

  For latest PACKETVER (>= 20150513), packet ID is 0x09FD.
  This is a variable-length packet with appearance and movement data.

  Object types:
  - 0x0: Player/PC
  - 0x1: NPC  
  - 0x5: Mob/Monster
  - 0x6: Homunculus
  - 0x7: Mercenary
  - 0x8: Elemental
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Utils

  @packet_id 0x09FD

  defstruct [
    :object_type,
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
    move_data = encode_move_data(packet.src_x, packet.src_y, packet.dst_x, packet.dst_y)
    name_binary = pack_string(Utils.get_field(packet.name, ""), 24)

    data = <<
      packet.object_type::8,
      packet.aid::32-little,
      packet.gid::32-little,
      packet.speed::16-little,
      packet.body_state::16-little,
      packet.health_state::16-little,
      packet.effect_state::32-little,
      packet.job::16-little,
      packet.head::16-little,
      packet.weapon::32-little,
      packet.shield::32-little,
      packet.accessory::16-little,
      packet.move_start_time::32-little,
      packet.accessory2::16-little,
      packet.accessory3::16-little,
      packet.head_palette::16-little,
      packet.body_palette::16-little,
      packet.head_dir::16-little,
      packet.robe::16-little,
      packet.guild_id::32-little,
      packet.guild_emblem_ver::16-little,
      packet.honor::16-little,
      packet.virtue::32-little,
      packet.is_pk_mode_on::8,
      packet.sex::8,
      move_data::binary,
      Utils.get_field(packet.x_size, 0)::8,
      Utils.get_field(packet.y_size, 0)::8,
      Utils.get_field(packet.clevel, 1)::16-little,
      Utils.get_field(packet.font, 0)::16-little,
      Utils.get_field(packet.max_hp, 0)::32-little,
      Utils.get_field(packet.hp, 0)::32-little,
      Utils.get_field(packet.is_boss, 0)::8,
      Utils.get_field(packet.body, 0)::16-little,
      name_binary::binary
    >>

    build_variable_packet(@packet_id, data)
  end
end
