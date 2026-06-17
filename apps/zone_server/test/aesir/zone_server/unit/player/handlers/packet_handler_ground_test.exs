defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerGroundTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzUseSkillToground
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler

  @cz_use_skill_toground 0x0AF4

  test "CZ_USE_SKILL_TOGROUND casts {:use_skill_ground, ...} to the session" do
    packet = %CzUseSkillToground{skill_id: 89, level: 3, x: 12, y: 24}

    assert {:noreply, state} = PacketHandler.handle_packet(@cz_use_skill_toground, packet, %{})
    assert state == %{}
    assert_received {:"$gen_cast", {:use_skill_ground, 89, 3, 12, 24}}
  end
end
