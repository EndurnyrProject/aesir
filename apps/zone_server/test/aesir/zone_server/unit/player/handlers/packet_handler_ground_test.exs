defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerGroundTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Net.GroundSkillCast
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler

  setup :verify_on_exit!

  test "GroundSkillCast dispatches to SkillHandler with the same skill/level/cell" do
    message = %GroundSkillCast{skill_id: 89, level: 3, x: 12, y: 24}

    expect(SkillHandler, :handle_use_skill_ground, fn state, 89, 3, 12, 24 ->
      {:noreply, state}
    end)

    assert {:noreply, %{}} = PacketHandler.handle_message(message, %{})
  end
end
