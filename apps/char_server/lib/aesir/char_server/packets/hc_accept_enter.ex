defmodule Aesir.CharServer.Packets.HcAcceptEnter do
  @moduledoc """
  HC_ACCEPT_ENTER packet (0x006b) - Character list response.

  Structure:
  - packet_type: 2 bytes (0x006b)
  - length: 2 bytes (total packet length)
  - characters: variable (character data)

  Each character entry (based on rathena structure):
  - char_id: 4 bytes
  - base_exp: 4 bytes  
  - zeny: 4 bytes
  - job_exp: 4 bytes
  - job_level: 4 bytes
  - opt1: 4 bytes
  - opt2: 4 bytes
  - option: 4 bytes
  - karma: 4 bytes
  - manner: 4 bytes
  - status_point: 2 bytes
  - hp: 2 bytes
  - max_hp: 2 bytes
  - sp: 2 bytes
  - max_sp: 2 bytes
  - walk_speed: 2 bytes
  - class: 2 bytes
  - hair: 2 bytes
  - weapon: 2 bytes
  - base_level: 2 bytes
  - skill_point: 2 bytes
  - head_bottom: 2 bytes
  - shield: 2 bytes
  - head_top: 2 bytes
  - head_mid: 2 bytes
  - hair_color: 2 bytes
  - clothes_color: 2 bytes
  - name: 24 bytes (null-terminated)
  - str: 1 byte
  - agi: 1 byte
  - vit: 1 byte
  - int: 1 byte
  - dex: 1 byte
  - luk: 1 byte
  - char_num: 1 byte
  - rename: 1 byte
  - map_name: 16 bytes
  - delete_date: 4 bytes
  - robe: 4 bytes
  - slot_change: 4 bytes
  - rename_flag: 4 bytes
  - body: 4 bytes

  Total: 106 bytes per character
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x006B
  @packet_size :variable

  defstruct [:characters]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, _length::16-little, _data::binary>>) do
    {:ok, %__MODULE__{characters: []}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{characters: characters}) do
    max_chars = 15
    min_chars = 9
    premium_chars = 9

    header_extension = <<
      # Max slots
      max_chars::8,
      # Available slots (PremiumStartSlot)
      min_chars::8,
      # Premium slots
      premium_chars::8,
      # 20 unknown bytes
      0::size(20 * 8)
    >>

    if Enum.empty?(characters) do
      packet_data = header_extension
      build_variable_packet(@packet_id, packet_data)
    else
      char_data =
        characters
        |> Enum.map(&serialize_character/1)
        |> IO.iodata_to_binary()

      packet_data = <<header_extension::binary, char_data::binary>>
      build_variable_packet(@packet_id, packet_data)
    end
  end

  defp serialize_character(character) do
    name = pack_string(character.name, 24)

    <<
      character.id::32-little,
      character.base_exp::64-little,
      character.zeny::32-little,
      character.job_exp::64-little,
      character.job_level::32-little,
      # bodystate (opt1)
      0::32-little,
      # healthstate (opt2)
      0::32-little,
      character.option::32-little,
      character.karma::32-little,
      character.manner::32-little,
      character.status_point::16-little,
      character.hp::64-little,
      character.max_hp::64-little,
      character.sp::64-little,
      character.max_sp::64-little,
      # speed (walk_speed default)
      150::16-little,
      character.class::16-little,
      character.hair::16-little,
      # body (for PACKETVER >= 20141022)
      0::16-little,
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
      character.hair_color::8,
      character.rename::16-little,
      pack_string(character.last_map || "prontera", 16)::binary,
      # DelRevDate (delete date)
      0::32-little,
      character.robe::32-little,
      # chr_slot_changeCnt
      0::32-little,
      character.rename::32-little,
      if(character.sex == "M", do: 1, else: 0)::8
    >>
  end
end
