defmodule Aesir.ZoneServer.Unit.Player.SessionStateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  test "builds from the enforced fields, defaulting the rest to nil" do
    game_state = %PlayerState{character_id: 1}
    pid = self()

    state = %SessionState{game_state: game_state, connection_pid: pid}

    assert state.game_state == game_state
    assert state.connection_pid == pid
    assert state.connection_monitor_ref == nil
    assert state.interaction_lock == nil
    assert state.pending_skill_menu == nil
    assert state.pending_party_invite == nil
    assert state.pending_guild_invite == nil
  end

  test "raises without the enforced fields" do
    assert_raise ArgumentError, fn ->
      struct!(SessionState, %{})
    end
  end
end
