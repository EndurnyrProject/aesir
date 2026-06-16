defmodule Aesir.ZoneServer.Packets.SkillPacketsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzUseSkill
  alias Aesir.ZoneServer.Packets.ZcSkillinfoList
  alias Aesir.ZoneServer.Packets.ZcUseSkill

  test "CzUseSkill parses level, skill_id and target_id" do
    bin = <<0x0113::16-little, 5::16-little, 29::16-little, 2000::32-little>>
    assert {:ok, %CzUseSkill{level: 5, skill_id: 29, target_id: 2000}} = CzUseSkill.parse(bin)
  end

  test "CzUseSkill rejects malformed data" do
    assert {:error, :invalid_packet} = CzUseSkill.parse(<<0x0113::16-little, 1::8>>)
  end

  test "ZcUseSkill builds a 15-byte packet" do
    packet = %ZcUseSkill{skill_id: 29, level: 5, dst_id: 1000, src_id: 1000}
    built = ZcUseSkill.build(packet)
    assert byte_size(built) == 15

    assert <<0x011A::16-little, 29::16-little, 5::16-little, 1000::32-little, 1000::32-little,
             1::8>> = built
  end

  test "ZcSkillinfoList builds one 37-byte block per learned skill (+4 header)" do
    packet = ZcSkillinfoList.from_learned(%{29 => 1})
    built = ZcSkillinfoList.build(packet)
    assert <<0x010F::16-little, length::16-little, _rest::binary>> = built
    assert length == 4 + 37
    assert byte_size(built) == 4 + 37
  end
end
