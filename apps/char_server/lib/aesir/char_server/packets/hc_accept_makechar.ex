defmodule Aesir.CharServer.Packets.HcAcceptMakechar do
  @moduledoc """
  HC_ACCEPT_MAKECHAR packet (0x006d) - Character creation success.

  This packet contains the new character's data in the same format as HC_ACCEPT_ENTER.
  Based on rathena, this is a fixed-size packet of 108 bytes.

  Structure:
  - packet_type: 2 bytes (0x006d)
  - character_data: 106 bytes (same format as character list entry)

  Total: 108 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x006D
  @packet_size 108

  defstruct [:character_data]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{character_data: character}) do
    # Pack character name and map name
    name = pack_string(character.name, 24)
    map_name = pack_string(elem(character.last_point, 0), 16)

    char_data = <<
      character.char_id::32-little,
      character.base_exp::32-little,
      character.zeny::32-little,
      character.job_exp::32-little,
      character.job_level::32-little,

      # opt1
      0::32-little,

      # opt2
      0::32-little,
      character.option::32-little,
      character.karma::32-little,
      character.manner::32-little,
      character.status_point::16-little,
      character.hp::16-little,
      character.max_hp::16-little,
      character.sp::16-little,
      character.max_sp::16-little,

      # walk_speed (default)
      150::16-little,
      character.class::16-little,
      character.hair::16-little,
      character.weapon::16-little,
      character.base_level::16-little,
      character.skill_point::16-little,
      character.head_bottom::16-little,
      character.shield::16-little,
      character.head_top::16-little,
      character.head_mid::16-little,
      character.hair_color::16-little,
      character.clothes_color::16-little,
      name::binary-size(24),
      character.str::8,
      character.agi::8,
      character.vit::8,
      character.int::8,
      character.dex::8,
      character.luk::8,
      character.char_num::8,
      character.rename_flag::8,
      map_name::binary-size(16),
      character.delete_date::32-little,
      character.robe::32-little,

      # slot_change
      0::32-little,
      character.rename_flag::32-little,
      character.body::32-little
    >>

    <<@packet_id::16-little, char_data::binary>>
  end
end
