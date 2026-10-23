defmodule Aesir.ZoneServer.Unit.Player.Handlers.PortalMenuActionsTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.SystemNotice
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillRequest

  setup :setup_ets_tables
  setup :set_mimic_private

  test "client skill requests still see the menu id, including item-granted target selection" do
    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1, action_state: :idle},
      pending_skill_menu: %{skill_id: 27, kind: :OPTIONS, work_in_progress?: false}
    }

    assert {:error, :busy} = SkillHandler.cast_gate(state, 27, :start)

    item_request = %{
      state
      | pending_item_skill: %{skill_id: 27, level: 1, keep_requirement?: false}
    }

    assert SkillRequest.ground(item_request, 27, 1, {10, 10}, 0) == {:refuse, :silent}
  end

  test "a portal menu blocks an NPC click but not the OnTouch fallback" do
    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1},
      pending_skill_menu: %{skill_id: 27, kind: :OPTIONS}
    }

    test_pid = self()

    stub(Registry, :module_for_unit, fn 123 ->
      send(test_pid, :touch_lookup)
      :error
    end)

    assert {:noreply, ^state} = NpcInteractionHandler.handle_talk(123, state)
    refute_received :touch_lookup
    assert {:noreply, ^state} = NpcInteractionHandler.talk_to_npc(123, state.game_state, state)
    assert_received :touch_lookup
  end

  @tag game_mode: :renewal
  test "renewal answers a click while busy with the busy notice" do
    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1},
      work_in_progress: true
    }

    assert {:noreply, ^state} = NpcInteractionHandler.handle_talk(123, state)

    assert_receive {:send, :gameplay, {:system_notice, %SystemNotice{id: :SYSTEM_NOTICE_ID_BUSY}}}
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal drops a click while busy silently" do
    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1},
      work_in_progress: true
    }

    assert {:noreply, ^state} = NpcInteractionHandler.handle_talk(123, state)
    refute_received {:send, :gameplay, {:system_notice, _}}
  end
end
