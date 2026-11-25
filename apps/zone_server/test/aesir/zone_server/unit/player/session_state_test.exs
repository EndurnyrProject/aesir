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

  describe "the stacked dialog lock" do
    setup do
      state = %SessionState{game_state: %PlayerState{character_id: 1}, connection_pid: self()}
      %{state: state, open: {self(), make_ref(), 1}, taker: {self(), make_ref(), 2}}
    end

    test "a free player is simply held", %{state: state, taker: taker} do
      held = SessionState.take_over_npc_dialog(state, taker)

      assert held.interaction_lock == taker
      assert held.dialog_backups == []
      assert {:released, %{interaction_lock: nil}} = SessionState.end_npc_dialog(held)
    end

    test "the open dialog waits beneath the taker and only takes its item flag back on resume",
         %{state: state, open: open, taker: taker} do
      state = %{state | interaction_lock: open, npc_item_flag: true}

      taken = SessionState.take_over_npc_dialog(state, taker)
      assert taken.interaction_lock == taker
      assert taken.npc_item_flag == nil
      assert taken.dialog_backups == [{open, true}]

      {:restored, restored} = SessionState.end_npc_dialog(%{taken | npc_item_flag: false})
      assert restored.interaction_lock == open
      assert restored.dialog_backups == []
      assert restored.npc_item_flag == false

      assert SessionState.resume_npc_dialog(restored).npc_item_flag == true
    end

    test "a dialog taken over again before it resumed keeps the flag it waits for",
         %{state: state, open: open, taker: taker} do
      state = %{state | interaction_lock: open, npc_item_flag: true}

      {:restored, restored} =
        state |> SessionState.take_over_npc_dialog(taker) |> SessionState.end_npc_dialog()

      again = SessionState.take_over_npc_dialog(%{restored | npc_item_flag: false}, taker)

      assert again.dialog_backups == [{open, true}]
    end
  end
end
