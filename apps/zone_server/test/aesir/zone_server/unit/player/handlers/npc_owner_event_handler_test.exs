defmodule Aesir.ZoneServer.Unit.Player.Handlers.NpcOwnerEventHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Npc.Events
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  defmodule EventNpc do
    def npc_id, do: :event_npc
  end

  setup :verify_on_exit!

  test "starts one owner event under the interaction lock" do
    interaction_pid = spawn(fn -> Process.sleep(:infinity) end)

    expect(Events, :trigger_attached, fn 77, "OnMyMobDead", ctx, session_pid ->
      assert ctx.char_id == 1000
      assert session_pid == self()
      {:ok, interaction_pid}
    end)

    assert {:noreply, started} =
             PlayerSession.handle_cast(
               {:npc, {:run_attached_event, EventNpc, 77, "OnMyMobDead"}},
               state()
             )

    assert {^interaction_pid, monitor_ref, 77} = started.interaction_lock
    assert is_reference(monitor_ref)
    Process.exit(interaction_pid, :kill)
  end

  test "pending skill text suppresses an owner event and remains active" do
    reject(&Events.trigger_attached/4)
    timer_ref = Process.send_after(self(), :unused_timeout, 60_000)

    pending = %SessionState.PendingSkillTextInput{
      request_id: 42,
      skill_id: 166,
      level: 1,
      target: {:ground, 1, 1},
      timer_ref: timer_ref
    }

    initial = %{state() | pending_skill_text_input: pending}

    assert {:noreply, unchanged} =
             PlayerSession.handle_cast(
               {:npc, {:run_attached_event, EventNpc, 77, "OnMyMobDead"}},
               initial
             )

    assert unchanged == initial
    assert is_integer(Process.read_timer(timer_ref))
  end

  defp state do
    %SessionState{
      game_state: %PlayerState{character_id: 1000, account_id: 2000},
      connection_pid: self()
    }
  end
end
