defmodule Aesir.CharServer.Packets.HcAcceptMakechar do
  @moduledoc """
  HC_ACCEPT_MAKECHAR packet (0x0B6F) - Character creation success.

  Structure:
  - packet_type: 2 bytes (0x0B6F)
  - character_data: 175 bytes (extended character data)

  Total: 177 bytes
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.Commons.Utils

  @packet_id 0x0B6F
  @packet_size 177

  defstruct [:character_data]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{character_data: character}) do
    char_data = serialize_character(character)

    <<@packet_id::16-little, char_data::binary>>
  end

  defp serialize_character(character) do
    name = pack_string(character.name, 24)
    map_name = pack_string(character.last_map, 16)
    rename_val = character.rename || 0
    is_changed_char_name = if rename_val > 0, do: 0, else: 1
    chr_name_change_cnt = if rename_val > 0, do: 1, else: 0
    sex = if character.sex == "M", do: 1, else: 0

    <<
      Utils.get_field(character.id, 0)::32-little,
      Utils.get_field(character.base_exp, 0)::64-little,
      Utils.get_field(character.zeny, 0)::32-little,
      Utils.get_field(character.job_exp, 0)::64-little,
      Utils.get_field(character.job_level, 1)::32-little,
      # bodystate
      0::32-little,
      # healthstate
      0::32-little,
      Utils.get_field(character.option, 0)::32-little,
      Utils.get_field(character.karma, 0)::32-little,
      Utils.get_field(character.manner, 0)::32-little,
      Utils.get_field(character.status_point, 0)::16-little,
      Utils.get_field(character.hp, 40)::64-little,
      Utils.get_field(character.max_hp, 40)::64-little,
      Utils.get_field(character.sp, 11)::64-little,
      Utils.get_field(character.max_sp, 11)::64-little,
      # speed
      150::16-little,
      Utils.get_field(character.class, 0)::16-little,
      Utils.get_field(character.hair, 1)::16-little,
      # body (for PACKETVER >= 20141022)
      0::16-little,
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
      Utils.get_field(character.char_num, 0)::8,
      Utils.get_field(character.hair_color, 0)::8,
      # bIsChangedCharName is int16 (2 bytes)
      is_changed_char_name::16-little,
      map_name::binary-size(16),
      # DelRevDate
      0::32-little,
      Utils.get_field(character.robe, 0)::32-little,
      # chr_slot_changeCnt
      0::32-little,
      chr_name_change_cnt::32-little,
      # sex
      sex::8
    >>
  end
end
