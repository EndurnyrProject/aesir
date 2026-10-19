defmodule Aesir.ZoneServer.Unit.Player.Handlers.PortalMenuActionsTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Unit.Player.Handlers.NpcInteractionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  setup :setup_ets_tables
  setup :set_mimic_private

  test "client skill requests still see the menu id, including item-granted target selection" do
    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1, action_state: :idle},
      pending_skill_menu: %{skill_id: 27, kind: :OPTIONS, work_in_progress?: false}
    }

    for phase <- [:start, :item] do
      assert {:error, :busy} = SkillHandler.cast_gate(state, 27, phase)
    end
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
end
