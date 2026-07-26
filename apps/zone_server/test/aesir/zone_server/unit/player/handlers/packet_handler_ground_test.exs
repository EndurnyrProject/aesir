defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerGroundTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SessionState.PendingSkillTextInput

  setup :verify_on_exit!

  test "GroundSkillCast dispatches to SkillHandler with the same skill/level/cell" do
    message = %GroundSkillCast{skill_id: 89, level: 3, x: 12, y: 24}

    expect(SkillHandler, :handle_use_skill_ground, fn state, 89, 3, 12, 24 ->
      {:noreply, state}
    end)

    assert {:noreply, %{}} = PacketHandler.handle_message(message, %{})
  end

  test "SkillTextInputReply dispatches to the staged-input handler" do
    timer_ref = Process.send_after(self(), :unused_timeout, 60_000)

    state = %SessionState{
      game_state: %PlayerState{character_id: 1},
      connection_pid: self(),
      pending_skill_text_input: %PendingSkillTextInput{
        request_id: 42,
        skill_id: 9_001,
        level: 1,
        target: {:ground, 12, 24},
        timer_ref: timer_ref
      }
    }

    message = %SkillTextInputReply{request_id: 42, outcome: {:cancel, true}}

    assert {:noreply, cleared} = PacketHandler.handle_message(message, state)
    assert cleared.pending_skill_text_input == nil
  end
end
