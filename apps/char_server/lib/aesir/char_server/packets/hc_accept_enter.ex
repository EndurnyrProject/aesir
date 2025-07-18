defmodule Aesir.CharServer.Packets.HcAcceptEnter do
  @moduledoc """
  HC_ACCEPT_ENTER packet (0x006b) - Character list response.

  This is a variable-length packet that contains the character list.

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
    # For now, just parse as empty character list
    {:ok, %__MODULE__{characters: []}}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{characters: characters}) do
    if Enum.empty?(characters) do
      # Empty character list - just header
      <<@packet_id::16-little, 4::16-little>>
    else
      # Serialize each character
      char_data =
        characters
        |> Enum.map(&serialize_character/1)
        |> IO.iodata_to_binary()

      # Build packet with header + character data
      build_variable_packet(@packet_id, char_data)
    end
  end

  defp serialize_character(character) do
    # Pack character name and map name
    name = pack_string(character.name, 24)
    map_name = pack_string(elem(character.last_point, 0), 16)

    <<
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
  end
end
