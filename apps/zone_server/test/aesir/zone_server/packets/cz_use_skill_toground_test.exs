defmodule Aesir.ZoneServer.Packets.CzUseSkillTogroundTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzUseSkillToground

  test "parses level, skill_id, x and y" do
    bin =
      <<0x0AF4::16-little, 10::16-little, 89::16-little, 150::16-little, 120::16-little, 0::8>>

    assert {:ok, %CzUseSkillToground{level: 10, skill_id: 89, x: 150, y: 120}} =
             CzUseSkillToground.parse(bin)
  end

  test "rejects malformed data" do
    assert {:error, :invalid_packet} = CzUseSkillToground.parse(<<0x0AF4::16-little, 1::8>>)
  end
end
