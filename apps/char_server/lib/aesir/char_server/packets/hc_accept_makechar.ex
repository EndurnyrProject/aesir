defmodule Aesir.CharServer.Packets.HcAcceptMakechar do
  @moduledoc """
  HC_ACCEPT_MAKECHAR packet (0x006d) - Character creation success.

  Structure:
  - packet_type: 2 bytes (0x006d)
  - character_data: 106 bytes (same format as character list entry)

  Total: 108 bytes
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Utils

  @packet_id 0x006D
  @packet_size 108

  defstruct [:character_data]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{character_data: character}) do
    name = pack_string(character.name, 24)
    map_name = pack_string(character.last_map, 16)

    char_data = <<
      character.id::32-little,
      Utils.get_field(character.base_exp, 0)::32-little,
      Utils.get_field(character.zeny, 0)::32-little,
      Utils.get_field(character.job_exp, 0)::32-little,
      Utils.get_field(character.job_level, 1)::32-little,
      0::32-little,
      0::32-little,
      Utils.get_field(character.option, 0)::32-little,
      Utils.get_field(character.karma, 0)::32-little,
      Utils.get_field(character.manner, 0)::32-little,
      Utils.get_field(character.status_point, 0)::16-little,
      Utils.get_field(character.hp, 40)::16-little,
      Utils.get_field(character.max_hp, 40)::16-little,
      Utils.get_field(character.sp, 11)::16-little,
      Utils.get_field(character.max_sp, 11)::16-little,
      150::16-little,
      Utils.get_field(character.class, 0)::16-little,
      Utils.get_field(character.hair, 1)::16-little,
      Utils.get_field(character.weapon, 0)::16-little,
      Utils.get_field(character.base_level, 1)::16-little,
      Utils.get_field(character.skill_point, 0)::16-little,
      Utils.get_field(character.head_bottom, 0)::16-little,
      Utils.get_field(character.shield, 0)::16-little,
      Utils.get_field(character.head_top, 0)::16-little,
      Utils.get_field(character.head_mid, 0)::16-little,
      Utils.get_field(character.hair_color, 0)::16-little,
      Utils.get_field(character.clothes_color, 0)::16-little,
      name::binary-size(24),
      Utils.get_field(character.str, 1)::8,
      Utils.get_field(character.agi, 1)::8,
      Utils.get_field(character.vit, 1)::8,
      Utils.get_field(character.int, 1)::8,
      Utils.get_field(character.dex, 1)::8,
      Utils.get_field(character.luk, 1)::8,
      character.char_num::8,
      Utils.get_field(character.rename, 0)::8,
      map_name::binary-size(16),
      0::32-little,
      Utils.get_field(character.robe, 0)::32-little,
      0::32-little,
      Utils.get_field(character.rename, 0)::32-little,
      0::32-little
    >>

    <<@packet_id::16-little, char_data::binary>>
  end
end
