defmodule Aesir.CharServer.Packets.HcAckCharinfoPerPage do
  @moduledoc """
  HC_ACK_CHARINFO_PER_PAGE packet (0x099d) - Character list response for refresh.

  This is sent in response to CH_CHARLIST_REQ (0x09A1).
  It contains the same character data as HC_ACCEPT_ENTER but without the header extension.

  Structure:
  - packet_id: 2 bytes (0x099d)
  - packet_length: 2 bytes
  - character_data: variable (106 bytes per character)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x099D
  @packet_size -1
  @char_size 106

  defstruct [:characters]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, length::16-little, data::binary>>) do
    data_size = length - 4

    if byte_size(data) >= data_size do
      <<char_data::binary-size(data_size), _rest::binary>> = data
      characters = parse_characters(char_data, [])
      {:ok, %__MODULE__{characters: characters}}
    else
      {:error, :incomplete_packet}
    end
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{characters: characters}) do
    char_data =
      characters
      |> Enum.map(&serialize_character/1)
      |> IO.iodata_to_binary()

    length = 4 + byte_size(char_data)

    main_packet = <<@packet_id::16-little, length::16-little, char_data::binary>>

    # Special handling: if exactly 3 characters, send an additional empty packet
    # This is a Gravity quirk that triggers client finalization
    if length(characters) == 3 do
      empty_packet = <<@packet_id::16-little, 4::16-little>>
      main_packet <> empty_packet
    else
      main_packet
    end
  end

  defp parse_characters(<<>>, acc), do: Enum.reverse(acc)

  defp parse_characters(data, acc) when byte_size(data) >= @char_size do
    <<char_data::binary-size(@char_size), rest::binary>> = data

    <<
      char_id::32-little,
      base_exp::32-little,
      zeny::32-little,
      job_exp::32-little,
      job_level::32-little,
      opt1::32-little,
      opt2::32-little,
      option::32-little,
      karma::32-little,
      manner::32-little,
      status_point::16-little,
      hp::16-little,
      max_hp::16-little,
      sp::16-little,
      max_sp::16-little,
      walk_speed::16-little,
      class::16-little,
      hair::16-little,
      weapon::16-little,
      base_level::16-little,
      skill_point::16-little,
      head_bottom::16-little,
      shield::16-little,
      head_top::16-little,
      head_mid::16-little,
      hair_color::16-little,
      clothes_color::16-little,
      name::binary-size(24),
      str::8,
      agi::8,
      vit::8,
      int::8,
      dex::8,
      luk::8,
      char_num::8,
      rename::8,
      map_name::binary-size(16),
      delete_date::32-little,
      robe::32-little,
      slot_change::32-little,
      rename::32-little,
      body::32-little
    >> = char_data

    character = %{
      char_id: char_id,
      base_exp: base_exp,
      zeny: zeny,
      job_exp: job_exp,
      job_level: job_level,
      opt1: opt1,
      opt2: opt2,
      option: option,
      karma: karma,
      manner: manner,
      status_point: status_point,
      hp: hp,
      max_hp: max_hp,
      sp: sp,
      max_sp: max_sp,
      walk_speed: walk_speed,
      class: class,
      hair: hair,
      weapon: weapon,
      base_level: base_level,
      skill_point: skill_point,
      head_bottom: head_bottom,
      shield: shield,
      head_top: head_top,
      head_mid: head_mid,
      hair_color: hair_color,
      clothes_color: clothes_color,
      name: extract_string(name),
      str: str,
      agi: agi,
      vit: vit,
      int: int,
      dex: dex,
      luk: luk,
      char_num: char_num,
      rename: rename,
      map_name: extract_string(map_name),
      delete_date: delete_date,
      robe: robe,
      slot_change: slot_change,
      rename_flag: rename,
      body: body
    }

    parse_characters(rest, [character | acc])
  end

  defp parse_characters(_data, acc), do: Enum.reverse(acc)

  defp serialize_character(character) do
    name = pack_string(character.name, 24)

    <<
      character.id::32-little,
      character.base_exp || 0::64-little,
      character.zeny || 0::32-little,
      character.job_exp || 0::64-little,
      character.job_level || 1::32-little,
      # bodystate (opt1)
      0::32-little,
      # healthstate (opt2)
      0::32-little,
      character.option || 0::32-little,
      character.karma || 0::32-little,
      character.manner || 0::32-little,
      character.status_point || 0::16-little,
      character.hp || 40::64-little,
      character.max_hp || 40::64-little,
      character.sp || 11::64-little,
      character.max_sp || 11::64-little,
      # speed
      150::16-little,
      character.class || 0::16-little,
      character.hair || 1::16-little,
      # body field
      0::16-little,
      character.weapon || 0::16-little,
      character.base_level || 1::16-little,
      character.skill_point || 0::16-little,
      character.head_bottom || 0::16-little,
      character.shield || 0::16-little,
      character.head_top || 0::16-little,
      character.head_mid || 0::16-little,
      character.hair_color || 0::16-little,
      character.clothes_color || 0::16-little,
      name::binary-size(24),
      character.str || 1::8,
      character.agi || 1::8,
      character.vit || 1::8,
      character.int || 1::8,
      character.dex || 1::8,
      character.luk || 1::8,
      character.char_num || character.slot || 0::8,
      character.hair_color || 0::8,
      character.rename || 0::16-little,
      pack_string(character.last_map || "prontera", 16)::binary,
      # DelRevDate
      0::32-little,
      character.robe || 0::32-little,
      # chr_slot_changeCnt
      0::32-little,
      character.rename || 0::32-little,
      if(character.sex == "M", do: 1, else: 0)::8
    >>
  end
end
