defmodule Aesir.ZoneServer.Packets.ZcNotifyNewentry do
  @moduledoc """
  ZC_NOTIFY_NEWENTRY11 (0x09FE) - Shows a spawning/appearing unit to other players.

  This packet tells clients about another unit that is spawning or appearing.
  Used when a unit spawns, teleports in, or logs in to the view range.

  For latest PACKETVER (>= 20150513), packet ID is 0x09FE.
  This is a variable-length packet with appearance data.

  Object types:
  - 0x0: Player/PC
  - 0x1: NPC  
  - 0x5: Mob/Monster
  - 0x6: Homunculus
  - 0x7: Mercenary
  - 0x8: Elemental
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x09FE

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
    pos_dir = encode_pos_dir(packet.x, packet.y, packet.dir || 0)
    name_binary = pack_string(packet.name || "", 24)

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
      pos_dir::binary,
      packet.x_size::8,
      packet.y_size::8,
      packet.clevel::16-little,
      packet.font::16-little,
      packet.max_hp::32-little,
      packet.hp::32-little,
      packet.is_boss::8,
      packet.body::16-little,
      name_binary::binary
    >>

    build_variable_packet(@packet_id, data)
  end
end
