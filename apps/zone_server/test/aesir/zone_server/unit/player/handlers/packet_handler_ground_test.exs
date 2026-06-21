defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerGroundTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.GroundSkillCast
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler

  test "GroundSkillCast casts {:use_skill_ground, ...} to the session" do
    message = %GroundSkillCast{skill_id: 89, level: 3, x: 12, y: 24}

    assert {:noreply, state} = PacketHandler.handle_message(message, %{})
    assert state == %{}
    assert_received {:"$gen_cast", {:use_skill_ground, 89, 3, 12, 24}}
  end
end
