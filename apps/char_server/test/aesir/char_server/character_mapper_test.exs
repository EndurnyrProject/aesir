defmodule Aesir.CharServer.CharacterMapperTest do
  use ExUnit.Case, async: true

  alias Aesir.CharServer.CharacterMapper
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
      sex: "M",
      delete_date: nil,
      pow: 30,
      sta: 20,
      wis: 15,
      spl: 25,
      con: 10,
      crt: 12,
      trait_point: 12,
      ap: 5,
      max_ap: 40
    }

    struct(base, overrides)
  end

  describe "to_proto/1" do
    test "maps all direct fields from the character model" do
      character = build_character()
      proto = CharacterMapper.to_proto(character)

      assert %Aesir.Net.Character{} = proto
      assert proto.gid == 150_000
      assert proto.name == "TestHero"
      assert proto.class == 4012
      assert proto.base_level == 99
      assert proto.job_level == 50
      assert proto.base_exp == 9_876_543_210
      assert proto.job_exp == 1_234_567_890
      assert proto.zeny == 2_000_000
      assert proto.hp == 11_500
      assert proto.max_hp == 12_000
      assert proto.sp == 2900
      assert proto.max_sp == 3000
      assert proto.str == 99
      assert proto.agi == 80
      assert proto.vit == 70
      assert proto.int == 60
      assert proto.dex == 90
      assert proto.luk == 50
      assert proto.status_point == 25
      assert proto.skill_point == 10
      assert proto.hair == 6
      assert proto.hair_color == 4
      assert proto.clothes_color == 2
      assert proto.shield == 2105
      assert proto.head_top == 2235
      assert proto.head_mid == 5001
      assert proto.head_bottom == 2201
      assert proto.robe == 19
      assert proto.char_num == 3
      assert proto.last_map == "prontera.gat"
      assert proto.option == @sit_down_option
      assert proto.karma == 7
      assert proto.manner == 13
      assert proto.rename == 0
      assert proto.pow == 30
      assert proto.sta == 20
      assert proto.wis == 15
      assert proto.spl == 25
      assert proto.con == 10
      assert proto.crt == 12
      assert proto.trait_point == 12
      assert proto.ap == 5
      assert proto.max_ap == 40
    end

    test "trait stats and AP round-trip through Character.encode/decode" do
      character = build_character()
      proto = CharacterMapper.to_proto(character)

      {:ok, iodata, _size} = Aesir.Net.Character.encode(proto)
      {:ok, decoded} = Aesir.Net.Character.decode(IO.iodata_to_binary(iodata))

      assert decoded.pow == 30
      assert decoded.sta == 20
      assert decoded.wis == 15
      assert decoded.spl == 25
      assert decoded.con == 10
      assert decoded.crt == 12
      assert decoded.trait_point == 12
      assert decoded.ap == 5
      assert decoded.max_ap == 40
    end

    test "maps sex 'M' to 1" do
      proto = CharacterMapper.to_proto(build_character(%{sex: "M"}))
      assert proto.sex == 1
    end

    test "maps sex 'F' to 0" do
      proto = CharacterMapper.to_proto(build_character(%{sex: "F"}))
      assert proto.sex == 0
    end

    test "zeroes weapon when riding bit is set in option" do
      character = build_character(%{option: @riding_option, weapon: 1201})
      proto = CharacterMapper.to_proto(character)
      assert proto.weapon == 0
    end

    test "keeps weapon value when no riding bit is set in option" do
      character = build_character(%{option: @sit_down_option, weapon: 1201})
      proto = CharacterMapper.to_proto(character)
      assert proto.weapon == 1201
    end

    test "maps nil delete_date to 0" do
      proto = CharacterMapper.to_proto(build_character(%{delete_date: nil}))
      assert proto.delete_date == 0
    end

    test "converts delete_date NaiveDateTime to unix integer" do
      delete_date = ~N[2030-01-01 00:00:00]
      proto = CharacterMapper.to_proto(build_character(%{delete_date: delete_date}))
      expected = delete_date |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
      assert proto.delete_date == expected
    end
  end
end
