defmodule Aesir.CharServer.Packets.HcAckCharinfoPerPageTest do
  use ExUnit.Case, async: true

  alias Aesir.CharServer.Packets.HcAckCharinfoPerPage
  alias Aesir.Commons.Models.Character

  @char_info_size 175

  defp build_character(overrides \\ %{}) do
    base = %Character{
      id: 150_000,
      account_id: 2000,
      char_num: 3,
      name: "TestHero",
      class: 4012,
      base_level: 99,
      job_level: 50,
      base_exp: 9_876_543_210,
      job_exp: 1_234_567_890,
      zeny: 2_000_000,
      str: 99,
      agi: 80,
      vit: 70,
      int: 60,
      dex: 90,
      luk: 50,
      max_hp: 12_000,
      hp: 11_500,
      max_sp: 3000,
      sp: 2900,
      status_point: 25,
      skill_point: 10,
      option: 0x02,
      karma: 7,
      manner: 13,
      hair: 6,
      hair_color: 4,
      clothes_color: 2,
      weapon: 1201,
      shield: 2105,
      head_top: 2235,
      head_mid: 5001,
      head_bottom: 2201,
      robe: 19,
      last_map: "prontera.gat",
      rename: 0,
      sex: "M"
    }

    struct(base, overrides)
  end

  describe "packet_id/0" do
    test "returns 0x0B72" do
      assert HcAckCharinfoPerPage.packet_id() == 0x0B72
    end
  end

  describe "build/1" do
    test "with 1 character: header is 0x0B72 and total size is 4 + 175" do
      characters = [build_character()]
      packet = HcAckCharinfoPerPage.build(%HcAckCharinfoPerPage{characters: characters})

      expected_len = 4 + @char_info_size
      assert byte_size(packet) == expected_len

      <<id::16-little, len::16-little, _char_data::binary>> = packet
      assert id == 0x0B72
      assert len == expected_len
    end

    test "with 2 characters: total size is 4 + 2*175" do
      characters = [build_character(), build_character(%{char_num: 1})]
      packet = HcAckCharinfoPerPage.build(%HcAckCharinfoPerPage{characters: characters})

      expected_len = 4 + 2 * @char_info_size
      assert byte_size(packet) == expected_len
    end

    test "per-character payload boundary is exactly 175 bytes after the 4-byte header" do
      characters = [build_character(), build_character(%{char_num: 1})]
      packet = HcAckCharinfoPerPage.build(%HcAckCharinfoPerPage{characters: characters})

      <<_header::binary-size(4), _char1::binary-size(@char_info_size), rest::binary>> = packet
      assert byte_size(rest) == @char_info_size
    end

    test "with exactly 3 characters: appends trailing empty 0x0B72 packet" do
      characters = [
        build_character(),
        build_character(%{char_num: 1}),
        build_character(%{char_num: 2})
      ]

      packet = HcAckCharinfoPerPage.build(%HcAckCharinfoPerPage{characters: characters})

      main_len = 4 + 3 * @char_info_size
      assert byte_size(packet) == main_len + 4

      trailing = binary_part(packet, main_len, 4)
      <<trailing_id::16-little, trailing_len::16-little>> = trailing
      assert trailing_id == 0x0B72
      assert trailing_len == 4
    end
  end
end
