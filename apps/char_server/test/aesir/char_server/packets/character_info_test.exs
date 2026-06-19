defmodule Aesir.CharServer.Packets.CharacterInfoTest do
  use ExUnit.Case, async: true

  alias Aesir.CharServer.Packets.CharacterInfo
  alias Aesir.Commons.Models.Character

  @sit_down_option 0x02
  @riding_option 0x20

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
      option: @sit_down_option,
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

  describe "byte_size/0" do
    test "returns 175" do
      assert CharacterInfo.byte_size() == 175
    end
  end

  describe "serialize/1" do
    test "produces exactly 175 bytes for a fully-populated character" do
      character = build_character()

      assert byte_size(CharacterInfo.serialize(character)) == 175
    end

    test "encodes the GID/exp/money/jobexp/joblevel header in rAthena field order" do
      character = build_character()

      <<gid::32-little, exp::64-little, money::32-little, jobexp::64-little, joblevel::32-little,
        _rest::binary>> = CharacterInfo.serialize(character)

      assert gid == character.id
      assert exp == character.base_exp
      assert money == character.zeny
      assert jobexp == character.job_exp
      assert joblevel == character.job_level
    end

    test "with rename: 0, bIsChangedCharName decodes to 1 and chr_name_changeCnt to 0" do
      character = build_character(%{rename: 0})

      binary = CharacterInfo.serialize(character)

      <<_::binary-size(140), is_changed_char_name::16-little, _::binary-size(28),
        chr_name_change_cnt::32-little, _::binary-size(1)>> = binary

      assert is_changed_char_name == 1
      assert chr_name_change_cnt == 0
    end

    test "with rename: 2, bIsChangedCharName decodes to 0 and chr_name_changeCnt to 1" do
      character = build_character(%{rename: 2})

      binary = CharacterInfo.serialize(character)

      <<_::binary-size(140), is_changed_char_name::16-little, _::binary-size(28),
        chr_name_change_cnt::32-little, _::binary-size(1)>> = binary

      assert is_changed_char_name == 0
      assert chr_name_change_cnt == 1
    end

    test "zeroes the weapon slot when a riding option flag is set" do
      character = build_character(%{option: @riding_option, weapon: 1201})

      binary = CharacterInfo.serialize(character)

      <<_::binary-size(90), weapon::16-little, _::binary>> = binary

      assert weapon == 0
    end

    test "keeps the weapon value when no riding flag is set" do
      character = build_character(%{option: @sit_down_option, weapon: 1201})

      binary = CharacterInfo.serialize(character)

      <<_::binary-size(90), weapon::16-little, _::binary>> = binary

      assert weapon == 1201
    end
  end
end
